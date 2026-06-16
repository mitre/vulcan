# frozen_string_literal: true

# component_sync_events is the per-merge audit row that ties together a
# snapshot (snapshot_path + archive_hash), a structured resolution log
# (resolution_log_json), and the downstream merge_operations and
# merge_quarantine entries via FK. parent_sync_id chains successive syncs
# for the same component. Schema per design doc §16.2 + card 480.7 ACs.
class CreateComponentSyncEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :component_sync_events do |t|
      t.references :component, null: false, foreign_key: true
      t.uuid :sync_id, null: false
      t.uuid :parent_sync_id
      t.string :source, null: false
      t.string :direction, null: false
      t.jsonb :resolution_log_json
      t.string :snapshot_path
      t.string :archive_hash
      t.string :status, null: false, default: 'pending'
      t.datetime :created_at, null: false
    end

    add_index :component_sync_events, :sync_id, unique: true
  end
end
