# frozen_string_literal: true

require 'bcrypt'

# This is our main user model, local, LDAP, and omniauth users are all stored here.
# We store provider and UID from the Omniauth provider that is logging a user in.
class User < ApplicationRecord
  # Raised when an OmniAuth login matches an existing user with a different provider
  class ProviderConflictError < StandardError; end
  # All non-omniauthable Devise modules MUST be in a single call so Devise can
  # properly coordinate their interactions. In particular, :timeoutable must be
  # in the same call as :rememberable so Devise checks remember-me tokens before
  # timing out a session. :omniauthable stays separate because it requires inline
  # provider configuration.
  devise :database_authenticatable, :registerable, :rememberable,
         :recoverable, :confirmable, :trackable, :validatable,
         :timeoutable, :lockable, :encryptable, :session_limitable, :session_traceable

  audited only: %i[admin name email], max_audits: 1000

  include ProjectMemberConstants
  include PasswordComplexityValidator

  devise :omniauthable, omniauth_providers: Devise.omniauth_providers

  validates :name, presence: true

  # AC-10: Skip session limiting when disabled via settings
  def skip_session_limitable?
    !Settings.session_limits&.enabled
  end

  before_create :skip_confirmation!, unless: -> { Settings.local_login.email_confirmation }
  after_create :promote_first_user_to_admin

  has_many :reviews, dependent: :nullify
  has_many :memberships, dependent: :destroy
  has_many :projects, through: :memberships, source: :membership, source_type: 'Project'
  has_many :components, through: :memberships, source: :membership, source_type: 'Component'
  has_many :access_requests, class_name: 'ProjectAccessRequest', dependent: :destroy

  scope :alphabetical, -> { order(:name) }

  # Transparent password migration from bcrypt to PBKDF2-SHA512.
  # On successful login with a bcrypt-hashed password, re-hashes with PBKDF2.
  #
  # TODO(FIPS): This migration path uses BCrypt for *verification only* of legacy
  # passwords — no new bcrypt hashes are created. Once migrated, the user's password
  # is stored as PBKDF2-SHA512. Evaluate whether read-only bcrypt verification during
  # migration affects FIPS 140-2 compliance posture, and determine a sunset date after
  # which unmigrated accounts should require a password reset instead.
  def valid_password?(password)
    if encrypted_password.start_with?('$2a$', '$2b$')
      # Legacy bcrypt password — verify with BCrypt directly
      result = BCrypt::Password.new(encrypted_password) == password
      if result
        # Re-hash with PBKDF2-SHA512 directly via encryptor to avoid
        # holding cleartext in @password (CodeQL rb/clear-text-storage-sensitive-data)
        new_salt = self.class.password_salt
        new_hash = encryptor_class.digest(password, self.class.stretches, new_salt, self.class.pepper)
        update_columns(encrypted_password: new_hash, password_salt: new_salt) # rubocop:disable Rails/SkipsModelValidations -- intentional: avoid callbacks during migration
      end
      result
    else
      super
    end
  end

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

    # SECURITY: Prevent provider hijacking — don't overwrite an existing account's provider
    if user.persisted? && user.provider != auth.provider
      existing_provider = user.provider || 'local'
      Rails.logger.warn "BLOCKED: User #{user.email} attempted login via '#{auth.provider}' " \
                        "but account exists with provider '#{existing_provider}'"
      raise ProviderConflictError,
            "An account with email #{user.email} already exists with #{existing_provider} authentication. " \
            'Please sign in using your original authentication method, or contact an administrator.'
    end

    if user.new_record?
      Rails.logger.info "Creating new user from OmniAuth: email=#{email}, provider=#{auth.provider}"
      user.provider = auth.provider
      user.uid = auth.uid
      user.name = auth.info.name.presence || "#{auth.provider} user"
      user.password = Devise.friendly_token
      user.skip_confirmation!
    else
      Rails.logger.info "Re-authenticating user from OmniAuth: email=#{email}, provider=#{auth.provider}"
      # Same provider — safe to update uid (e.g., provider re-issues uid)
      user.uid = auth.uid
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

  private

  # Promotes the first user to admin if VULCAN_FIRST_USER_ADMIN is enabled
  # and no admin users exist yet. This makes Docker deployments functional
  # immediately without manual admin setup.
  #
  # Uses advisory lock to prevent race condition where multiple concurrent
  # registrations could all become admin. See:
  # - https://github.com/ClosureTree/with_advisory_lock
  # - WordPress installer race condition vulnerability for why this matters
  def promote_first_user_to_admin
    return unless Settings.admin_bootstrap.first_user_admin

    # Use advisory lock to ensure only one user can be promoted to admin
    # The lock name is application-wide since we're checking for ANY admin
    User.with_advisory_lock('vulcan_first_user_admin_promotion', timeout_seconds: 5) do
      # Re-check inside lock to handle race condition
      return if User.exists?(admin: true)

      update_column(:admin, true) # rubocop:disable Rails/SkipsModelValidations -- intentional: avoid callback loop inside after_create
      Rails.logger.info "First user #{email} promoted to admin (VULCAN_FIRST_USER_ADMIN=true)"
    end
  end
end
