# frozen_string_literal: true

# Same archive bytes can't be applied to the same component
# twice. Partial unique index on (component_id, archive_hash) WHERE
# archive_hash IS NOT NULL AND status='applied' prevents literal-byte
# replays. Note: this does NOT catch two different exports of identical
# DB state — archive_hash is computed over the raw zip, which carries
# the manifest exported_at and zip mtimes (separate follow-up to
# canonicalize the hash input).
class AddUniqueAppliedArchiveHashIndex < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :component_sync_events, %i[component_id archive_hash],
              unique: true,
              where: "archive_hash IS NOT NULL AND status = 'applied'",
              name: 'index_component_sync_events_on_applied_archive_hash',
              algorithm: :concurrently,
              if_not_exists: true
  end
end
