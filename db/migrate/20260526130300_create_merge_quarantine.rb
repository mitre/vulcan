# frozen_string_literal: true

# merge_quarantine holds raw archive records that failed validation during
# a merge (cross-rule reply, missing FK target, invalid enum, etc.).
# Operators inspect quarantined rows in the merge UI, fix the underlying
# issue (e.g., re-parent a comment), and retry via
# `rake sync:retry_quarantined MERGE_EVENT=uuid`. Cleanup via
# `rake sync:clear_quarantine MERGE_EVENT=uuid`. Design doc §17.1.
class CreateMergeQuarantine < ActiveRecord::Migration[8.0]
  def change
    create_table :merge_quarantine do |t|
      t.references :component_sync_event, null: false, foreign_key: true
      t.string :entity_type, null: false
      t.string :entity_key, null: false
      t.string :quarantine_reason, null: false
      t.jsonb :original_archive_data, null: false
      t.jsonb :validation_errors
      t.timestamps
    end
  end
end
