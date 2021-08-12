# frozen_string_literal: true

# This is our main user model, local, LDAP, and omniauth users are all stored here.
# We store provider and UID from the Omniauth provider that is logging a user in.
class User < ApplicationRecord
  include ProjectMemberConstants

  devise :database_authenticatable, :registerable, :rememberable, :recoverable, :confirmable, :trackable, :validatable

  devise :omniauthable, omniauth_providers: Devise.omniauth_providers

  validates :name, presence: true

  before_create :skip_confirmation!, unless: -> { Settings.local_login.email_confirmation }

  has_many :comments, dependent: :nullify
  has_many :project_members, dependent: :destroy
  has_many :projects, through: :project_members

  scope :alphabetical, -> { order(:name) }

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

  def can_edit_project?(project)
    admin || project.project_members.where(user_id: id, role: PROJECT_MEMBER_EDITORS).any?
  end

  def can_review_project(project)
    admin || project.project_members.where(user_id: id, role: PROJECT_MEMBER_REVIEWERS).any?
  end

  def can_admin_project?(project)
    admin || project.project_members.where(user_id: id, role: PROJECT_MEMBER_ADMINS).any?
  end
end
