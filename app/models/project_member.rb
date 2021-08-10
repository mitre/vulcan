# frozen_string_literal: true

# A ProjectMember is the has_many: :through Model that stores information
# about a User's membership of a Project
class ProjectMember < ApplicationRecord
  include ProjectMemberConstants

  belongs_to :project
  belongs_to :user

  validates :role, inclusion: {
    in: PROJECT_MEMBER_ROLES,
    message: "is not an acceptable value. Acceptable values are: #{PROJECT_MEMBER_ROLES.join(', ')}"
  }

  validates :user, uniqueness: {
    scope: :project,
    message: 'is already a member of this project.'
  }
end
