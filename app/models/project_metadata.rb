# frozen_string_literal: true

class ProjectMetadata < ApplicationRecord
  belongs_to :project

  validates :project, uniqueness: { message: 'already has associated metadata' }
end
