# frozen_string_literal: true

##
# ProjectAccessRequest represents a user's request to access a specific project
class ProjectAccessRequest < ApplicationRecord
  belongs_to :user
  belongs_to :project

  validates :user_id, uniqueness: { scope: :project_id, message: 'has already requested access to this project' }
end
