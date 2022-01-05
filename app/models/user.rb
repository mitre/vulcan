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

  before_create :skip_confirmation!, unless: -> { Settings.local_login.email_confirmation }

  has_many :reviews, dependent: :nullify
  has_many :memberships, dependent: :destroy
  has_many :projects, through: :memberships, source: :membership, source_type: 'Project'
  has_many :components, through: :memberships, source: :membership, source_type: 'Component'

  scope :alphabetical, -> { order(:name) }

  def available_projects
    admin ? Project.all : projects
  end

  def self.from_omniauth(auth)
    find_or_create_by(email: auth.info.email) do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 50]
      user.name = auth.info.name || "#{auth.provider} user"
      user.provider = auth.provider
      user.uid = auth.uid

      user.skip_confirmation!
    end
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
    admin || (PROJECT_MEMBER_AUTHORS.include?(effective_permissions(component)) unless component.released)
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
