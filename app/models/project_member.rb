# frozen_string_literal: true

# A ProjectMember is the has_many: :through Model that stores information
# about a User's membership of a Project
class ProjectMember < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validates :role, inclusion: {
    in: %w[admin reviewer editor],
    message: 'is not an acceptable value. Acceptable values are: \'admin\', \'reviewer\', or \'editor\''
  }
end
