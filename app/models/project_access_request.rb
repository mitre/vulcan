# frozen_string_literal: true

class ProjectAccessRequest < ApplicationRecord
  belongs_to :user
  belongs_to :project

  validates :user_id, uniqueness: { scope: :project_id, message: 'has already requested access to this project' }
end
