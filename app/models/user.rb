# frozen_string_literal: true

# This is our main user model, local, LDAP, and omniauth users are all stored here.
# We store provider and UID from the Omniauth provider that is logging a user in.
class User < ApplicationRecord
  audited only: %i[admin name email], max_audits: 1000

  include ProjectMemberConstants

  devise :database_authenticatable, :registerable, :rememberable, :recoverable, :confirmable, :trackable, :validatable

  devise :omniauthable, omniauth_providers: Devise.omniauth_providers

  validates :name, presence: true

  before_create :skip_confirmation!, unless: -> { Settings.local_login.email_confirmation }

  has_many :reviews, dependent: :nullify
  has_many :project_members, dependent: :destroy
  has_many :projects, through: :project_members

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

  def can_author_project?(project)
    admin || project.project_members.where(user_id: id, role: PROJECT_MEMBER_AUTHORS).any?
  end

  def can_review_project?(project)
    admin || project.project_members.where(user_id: id, role: PROJECT_MEMBER_REVIEWERS).any?
  end

  def can_admin_project?(project)
    admin || project.project_members.where(user_id: id, role: PROJECT_MEMBER_ADMINS).any?
  end

  ##
  # Get the effective permissions on a specific project for the user
  #
  def effective_permissions(project_or_component)
    return nil if project_or_component.nil?

    return 'admin' if admin

    member_search_ids = case project_or_component
                        when Project
                          [project_or_component.id]
                        when Component
                          [project_or_component.project_id]
                        else
                          []
                        end
    ProjectMember.where(project_id: member_search_ids).find_by(user_id: id)&.role
  end
end
