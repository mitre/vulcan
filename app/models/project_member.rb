# frozen_string_literal: true

# A ProjectMember is the has_many: :through Model that stores information
# about a User's membership of a Project
class ProjectMember < ApplicationRecord
  audited except: %i[id created_at updated_at], max_audits: 1000, associated_with: :project

  include ProjectMemberConstants

  belongs_to :project, counter_cache: true
  belongs_to :user

  delegate :name, to: :user
  delegate :email, to: :user

  scope :alphabetical, -> { joins(:user).order('users.name ASC') }

  validates :role, inclusion: {
    in: PROJECT_MEMBER_ROLES,
    message: "is not an acceptable value. Acceptable values are: #{PROJECT_MEMBER_ROLES.join(', ')}"
  }

  validates :user, uniqueness: {
    scope: :project,
    message: 'is already a member of this project.'
  }

  ##
  # Override `as_json` to include additional attributes about the associated user.
  # This is useful for the ProjectMember.vue component.
  #
  def as_json(options = {})
    super options.merge(methods: %i[name email])
  end
end
