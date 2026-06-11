# frozen_string_literal: true

# Only one pending ComponentSyncEvent per component at a time.
# Backstops the applier's pg_advisory_xact_lock + reload-locked precondition
# pattern — two operators racing sync:apply both see comment_phase='closed'
# and try to create a pending event; the loser is rejected at this constraint.
class AddUniquePendingComponentSyncEventIndex < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :component_sync_events, :component_id,
              unique: true,
              where: "status = 'pending'",
              name: 'index_component_sync_events_on_pending_component',
              algorithm: :concurrently,
              if_not_exists: true
  end
end
