# frozen_string_literal: true

# PR-717 review remediation .7 — backfill associated_id / associated_type
# for existing Review audits.
#
# Pre-PR-717 (and pre-this-migration), Review audits were written with NULL
# `associated_id` / `associated_type` because vulcan_audited didn't declare
# `associated_with: :rule`. Now that the model declares it, NEW audits
# carry the association — but legacy rows are still NULL and won't surface
# in `Audited::Audit.where(associated_type: 'BaseRule', associated_id: …)`
# rule-scoped queries. Backfill them in one PG UPDATE-FROM-JOIN.
#
# Audit rows whose auditable Review has been destroyed (admin_destroy
# cascade) are skipped by the INNER JOIN — they remain orphaned, which
# matches their pre-migration state.
class BackfillReviewAuditAssociations < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE audits
      SET associated_id = reviews.rule_id,
          associated_type = 'BaseRule'
      FROM reviews
      WHERE audits.auditable_type = 'Review'
        AND audits.auditable_id = reviews.id
        AND audits.associated_id IS NULL
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE audits
      SET associated_id = NULL,
          associated_type = NULL
      WHERE auditable_type = 'Review'
        AND associated_type = 'BaseRule'
    SQL
  end
end
