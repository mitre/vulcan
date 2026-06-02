# frozen_string_literal: true

# Project-scoped canned response for triage replies. Triagers select from
# a dropdown to populate the response textarea; admins manage the library.
class TriageResponseTemplate < ApplicationRecord
  belongs_to :project
  belongs_to :created_by, class_name: 'User'

  validates :name, presence: true, length: { maximum: 200 }
  validates :body, presence: true
  validates :name, uniqueness: { scope: :project_id, case_sensitive: false }

  scope :for_project, ->(project) { where(project: project).order(:name) }
end
