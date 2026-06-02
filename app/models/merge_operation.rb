# frozen_string_literal: true

# One row per field write during a merge. Carries old_value/new_value plus
# the natural entity_key (rule_id string or review match key) so surgical
# undo (§17.3) can target the right field on the right entity even if
# DB ids changed between merges.
class MergeOperation < ApplicationRecord
  OPERATIONS = %w[insert update skip].freeze
  SOURCES    = %w[ours theirs auto_merge conflict_resolved].freeze

  belongs_to :component_sync_event

  validates :entity_type, :entity_id, :entity_key, :operation, :source, presence: true
  validates :operation, inclusion: { in: OPERATIONS }
  validates :source,    inclusion: { in: SOURCES }
end
