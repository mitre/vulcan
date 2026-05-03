# frozen_string_literal: true

# PR-717 review remediation .1 — the original lifecycle migration
# (20260429145530_add_lifecycle_columns_to_reviews) added
# `triage_status` as NOT NULL DEFAULT 'pending'. On instances upgrading
# with pre-PR-717 `comment` reviews already in the DB, every legacy row
# was instantly populated with 'pending' and showed up in the public-
# comment triage queue — even though those rows had nothing to do with a
# public comment workflow.
#
# Aaron decision (option a): drop the default + allow NULL + backfill
# legacy rows. NULL is the correct sentinel for "this row was not part of
# a public-comment workflow"; 'pending' remains a real workflow state for
# comments posted during an open period (set explicitly by the model on
# create — see app/models/review.rb).
#
# Backfill scope (Aaron preference for simplicity over time-comparison):
# any review whose component has `comment_period_starts_at IS NULL`
# (the component never opened a public-comment period). Components that
# already opened a period keep their per-row state — those rows are real
# triage candidates.
class MakeReviewTriageStatusNullable < ActiveRecord::Migration[8.0]
  def up
    change_column_default :reviews, :triage_status, from: 'pending', to: nil
    change_column_null :reviews, :triage_status, true

    # Backfill legacy rows. update_all with raw SQL avoids loading every
    # row into memory and skips audited callbacks (we don't want a
    # destruction-of-state audit on every legacy row — the migration's
    # commit message is the audit trail).
    execute <<~SQL.squish
      UPDATE reviews
         SET triage_status = NULL
       WHERE id IN (
         SELECT r.id
           FROM reviews r
           JOIN base_rules ru ON ru.id = r.rule_id
           JOIN components c  ON c.id = ru.component_id
          WHERE c.comment_period_starts_at IS NULL
       )
    SQL
  end

  def down
    # Restore the original constraint shape. Rows that were backfilled to
    # NULL get rolled forward to 'pending' so the NOT NULL re-add
    # succeeds. Note: this round-trips the DATA back to the buggy state
    # — only run `down` in dev for migration round-trip tests.
    execute "UPDATE reviews SET triage_status = 'pending' WHERE triage_status IS NULL"
    change_column_null :reviews, :triage_status, false
    change_column_default :reviews, :triage_status, from: nil, to: 'pending'
  end
end
