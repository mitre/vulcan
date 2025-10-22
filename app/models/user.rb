# frozen_string_literal: true

# This is our main user model, local, LDAP, and omniauth users are all stored here.
# We store provider and UID from the Omniauth provider that is logging a user in.
class User < ApplicationRecord
  devise :timeoutable

  audited only: %i[admin name email], max_audits: 1000

  include ProjectMemberConstants

  devise :database_authenticatable, :registerable, :rememberable, :recoverable, :confirmable, :trackable, :validatable

  devise :omniauthable, omniauth_providers: Devise.omniauth_providers

  validates :name, presence: true
  # Enhanced email validation beyond Devise's basic format check
  # Validates format and blocks disposable email providers
  validates :email, 'valid_email_2/email': { disposable: true }

  before_create :skip_confirmation!, unless: -> { Settings.local_login.email_confirmation }

  has_many :reviews, dependent: :nullify
  has_many :memberships, dependent: :destroy
  has_many :projects, through: :memberships, source: :membership, source_type: 'Project'
  has_many :components, through: :memberships, source: :membership, source_type: 'Component'
  has_many :access_requests, class_name: 'ProjectAccessRequest', dependent: :destroy

  scope :alphabetical, -> { order(:name) }

  def available_projects
    admin ? Project.all : Project.where(id: projects.pluck(:id)).or(Project.discoverable).distinct
  end

  def self.from_omniauth(auth)
    # Extract and validate email from multiple sources
    email = extract_email_from_auth(auth)

    # Validate extracted email
    if email.blank?
      Rails.logger.error "Cannot create user from OmniAuth: no email found in auth hash for provider: #{auth.provider}"
      raise ArgumentError, 'Email is required but was not found in the authentication response'
    end

    # Use transaction with retry logic to handle race conditions
    retry_count = 0
    begin
      ActiveRecord::Base.transaction do
        create_or_update_user_from_auth(email, auth)
      end
    rescue ActiveRecord::RecordNotUnique => e
      # Handle race condition where multiple requests try to create the same user
      retry_count += 1
      if retry_count <= 2
        Rails.logger.warn "Race condition detected for email #{email}, retrying (attempt #{retry_count})"
        sleep(0.1 * retry_count) # Brief backoff
        retry
      else
        Rails.logger.error "Failed to create user after #{retry_count} attempts: #{e.message}"
        raise e
      end
    end
  rescue StandardError => e
    Rails.logger.error "Failed to create/update user from OmniAuth: #{e.message}"
    Rails.logger.debug e.backtrace.join("\n") if Rails.env.development?
    raise
  end

  private_class_method def self.extract_email_from_auth(auth)
    # Try multiple sources for email, including LDAP-specific attributes
    email = auth.info.email ||
            (auth.extra&.raw_info.respond_to?(:acct) ? auth.extra.raw_info.acct : nil) ||
            (auth.provider == 'ldap' && auth.extra&.raw_info.respond_to?(:mail) ? auth.extra.raw_info.mail : nil) ||
            (auth.provider == 'ldap' && auth.extra&.raw_info.respond_to?(:[]) ? auth.extra.raw_info['mail'] : nil)

    # Handle case where LDAP returns email as an array - find first valid email
    email = email.compact_blank.first if email.is_a?(Array)

    # Log what we found for debugging
    Rails.logger.debug { "Attempting to find email from OmniAuth - provider: #{auth.provider}, found: #{email}" }

    email
  end

  private_class_method def self.create_or_update_user_from_auth(email, auth)
    # Use downcase to ensure case-insensitive lookup consistent with Devise configuration
    # This prevents "Email has already been taken" errors when users login with different email casing
    user = find_or_initialize_by(email: email.downcase)

    # Log provider switching for security auditing
    if user.persisted? && user.provider != auth.provider
      Rails.logger.warn "User #{user.email} switching authentication provider " \
                        "from '#{user.provider}' to '#{auth.provider}'"
      Rails.logger.info "Previous UID: #{user.uid}, New UID: #{auth.uid}"
    end

    if user.new_record?
      Rails.logger.info "Creating new user from OmniAuth: email=#{email}, provider=#{auth.provider}"
    else
      Rails.logger.info "Updating existing user from OmniAuth: email=#{email}, " \
                        "provider=#{auth.provider}, previous_provider=#{user.provider}"
    end

    # Always update provider and uid for existing users
    user.provider = auth.provider
    user.uid = auth.uid

    # Only update name if it's blank (preserve existing names)
    user.name = auth.info.name.presence || "#{auth.provider} user" if user.name.blank?

    # Only set password and skip confirmation for new users
    if user.new_record?
      # Use full-length secure token for better entropy
      user.password = Devise.friendly_token
      user.skip_confirmation!
    end

    user.save!
    Rails.logger.info "User #{user.email} successfully authenticated via #{auth.provider}"
    user
  end

  # Project permssions checking
  def can_view_project?(project)
    admin || project.memberships.where(user_id: id, role: PROJECT_MEMBER_VIEWERS).any?
  end

  def can_author_project?(project)
    admin || project.memberships.where(user_id: id, role: PROJECT_MEMBER_AUTHORS).any?
  end

  def can_review_project?(project)
    admin || project.memberships.where(user_id: id, role: PROJECT_MEMBER_REVIEWERS).any?
  end

  def can_admin_project?(project)
    admin || project.memberships.where(user_id: id, role: PROJECT_MEMBER_ADMINS).any?
  end

  # Component permissions checking
  def can_view_component?(component)
    admin || PROJECT_MEMBER_VIEWERS.include?(effective_permissions(component))
  end

  def can_author_component?(component)
    return true if admin
    return false if component.released

    PROJECT_MEMBER_AUTHORS.include?(effective_permissions(component))
  end

  def can_review_component?(component)
    admin || PROJECT_MEMBER_REVIEWERS.include?(effective_permissions(component))
  end

  def can_admin_component?(component)
    admin || effective_permissions(component) == 'admin'
  end

  ##
  # Get the effective permissions on a specific project for the user
  #
  def effective_permissions(project_or_component)
    return nil if project_or_component.nil?

    return 'admin' if admin

    case project_or_component
    when Project
      Membership.where(
        membership_type: 'Project',
        membership_id: project_or_component.id,
        user_id: id
      ).pick(:role)
    when Component
      memberships = Membership.where(
        membership_type: 'Project',
        membership_id: project_or_component.project_id,
        user_id: id
      ).or(
        Membership.where(
          membership_type: 'Component',
          membership_id: project_or_component.id,
          user_id: id
        )
      ).pluck(:role)
      # Pick the greater of the two possible permissions
      memberships.max do |role_a, role_b|
        PROJECT_MEMBER_ROLES.index(role_a) <=> PROJECT_MEMBER_ROLES.index(role_b)
      end
    end
  end
end
