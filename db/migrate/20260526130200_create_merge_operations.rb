# frozen_string_literal: true

# Per-field operation log for surgical undo (design doc §17.3). Each merge
# writes one row per field write so a later operator can revert merge B's
# changes without disturbing earlier merge A or later merge C. entity_key
# stores the natural key (rule_id string or review match key) so the row
# survives DB id remaps.
class CreateMergeOperations < ActiveRecord::Migration[8.0]
  def change
    create_table :merge_operations do |t|
      t.references :component_sync_event, null: false, foreign_key: true
      t.string :entity_type, null: false
      t.bigint :entity_id, null: false
      t.string :entity_key, null: false
      t.string :operation, null: false
      t.string :field_name
      t.text :old_value
      t.text :new_value
      t.string :source, null: false
      t.timestamps
    end
  end
end
