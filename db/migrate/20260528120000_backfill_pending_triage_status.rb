# frozen_string_literal: true

# Imported top-level comments could land with triage_status=NULL: bulk
# Review.insert! bypasses Review#default_triage_status_for_new_top_level_comment.
# A top-level comment with no status is semantically pending; NULL makes it fall
# out of every status bucket (miscounted, unreachable via the status filter).
# Replies (responding_to_review_id present) legitimately keep NULL.
class BackfillPendingTriageStatus < ActiveRecord::Migration[8.0]
  def up
    execute(<<~SQL.squish)
      UPDATE reviews
      SET triage_status = 'pending'
      WHERE action = 'comment'
        AND responding_to_review_id IS NULL
        AND triage_status IS NULL
    SQL
  end

  def down
    # No-op: backfilled rows are indistinguishable from organically-pending
    # ones, and reverting pending -> NULL would re-introduce the bug.
  end
end
