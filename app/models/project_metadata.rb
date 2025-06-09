# frozen_string_literal: true

##
# ProjectMetadata stores additional metadata for projects in a flexible JSON structure
class ProjectMetadata < ApplicationRecord
  belongs_to :project

  validates :project, uniqueness: { message: 'already has associated metadata' }
end
