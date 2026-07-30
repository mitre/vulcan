# frozen_string_literal: true

# Core-ness is recognition of the three DISA-published core documents by
# benchmark id (see SecurityRequirementsGuide::CORE_SRG_IDS). Recognition
# now happens at creation; this backfill flags rows that predate it, on
# every release of the three documents (the benchmark id is stable across
# releases). Idempotent — re-running matches zero unflagged rows.
class BackfillCoreSrgRecognition < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # The model constant is the ONE home for the three DISA benchmark ids;
    # this migration already depends on the model for the query, so it
    # reads the list from the same place rather than carrying a copy.
    SecurityRequirementsGuide.where(srg_id: SecurityRequirementsGuide::CORE_SRG_IDS, core: false)
                             .in_batches(of: 100)
                             .update_all(core: true)
  end

  def down
    # Recognition is derived from DISA's published identity — unflagging
    # would misstate the documents; intentionally irreversible.
    raise ActiveRecord::IrreversibleMigration
  end
end
