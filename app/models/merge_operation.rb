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
  # entity_id is a live PK on the receiving instance — surgical undo
  # (§17.3) needs it to locate the affected row. A 0 / negative value
  # would silently break undo. Catches the regression where
  # log_review_insert hardcoded entity_id: 0.
  validates :entity_id, numericality: { only_integer: true, greater_than: 0 }
  validates :operation, inclusion: { in: OPERATIONS }
  validates :source,    inclusion: { in: SOURCES }
end
