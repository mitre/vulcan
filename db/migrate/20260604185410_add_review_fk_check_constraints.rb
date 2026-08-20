# frozen_string_literal: true

# Pass 1 of 2 (Strong Migrations canonical pattern).
# Backfills stale FK data, then adds CHECK constraints with
# validate: false so the table is not held under ACCESS EXCLUSIVE
# while existing rows are validated. The companion migration
# (20260604185411) validates inside disable_ddl_transaction!.
#
# Uses IS NOT DISTINCT FROM (NULL-safe equality) so that
# triage_status IS NULL + non-null FK is also rejected.
# Standard SQL equality would let that combination through
# because NULL = 'duplicate' evaluates to NULL, and CHECK
# constraints only reject FALSE, not NULL.
class AddReviewFkCheckConstraints < ActiveRecord::Migration[8.0]
  def up
    # Backfill: clear stale FKs that would violate the new constraints.
    # Matches the intent of Review#clear_stale_foreign_keys callback.
    execute <<~SQL.squish
      UPDATE reviews
         SET duplicate_of_review_id = NULL
       WHERE triage_status IS DISTINCT FROM 'duplicate'
         AND duplicate_of_review_id IS NOT NULL
    SQL

    execute <<~SQL.squish
      UPDATE reviews
         SET addressed_by_rule_id = NULL
       WHERE triage_status IS DISTINCT FROM 'addressed_by'
         AND addressed_by_rule_id IS NOT NULL
    SQL

    add_check_constraint :reviews,
                         "triage_status IS NOT DISTINCT FROM 'duplicate' OR duplicate_of_review_id IS NULL",
                         name: 'chk_review_duplicate_fk_consistency',
                         validate: false

    add_check_constraint :reviews,
                         "triage_status IS NOT DISTINCT FROM 'addressed_by' OR addressed_by_rule_id IS NULL",
                         name: 'chk_review_addressed_by_fk_consistency',
                         validate: false
  end

  def down
    remove_check_constraint :reviews, name: 'chk_review_duplicate_fk_consistency'
    remove_check_constraint :reviews, name: 'chk_review_addressed_by_fk_consistency'
  end
end
