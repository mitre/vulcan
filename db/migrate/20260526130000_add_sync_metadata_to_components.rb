# frozen_string_literal: true

# Component sync metadata — pointers to the last sync that touched this
# component, so MergeAnalyzer can show a "last synced …" header and detect
# replay attempts. Read-only during merge analysis; no index needed.
# Design doc §9. Part of vulcan-v3.x-480.7 (Phase 2a).
class AddSyncMetadataToComponents < ActiveRecord::Migration[8.0]
  def change
    change_table :components, bulk: true do |t|
      t.column :last_sync_id, :uuid, null: true
      t.column :last_sync_at, :datetime, null: true
      t.column :last_sync_source, :string, null: true
    end
  end
end
