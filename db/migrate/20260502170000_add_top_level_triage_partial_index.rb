# frozen_string_literal: true

# PR-717 review remediation .17 — partial index covering the triage
# queue's natural shape. Component#paginated_comments runs:
#
#   Review.top_level_comments.where(triage_status: 'pending')
#     .joins(:rule).merge(Rule.where(component_id: id))
#     .order(created_at: :desc)
#     .offset(...).limit(...)
#
# `top_level_comments` is `where(action: 'comment', responding_to_review_id: nil)`.
# Pre-fix, no index covers (action='comment' AND responding_to IS NULL)
# with a leading triage_status. The planner falls back to the
# `index_reviews_on_action_and_triage_status` btree (full table scope by
# action + status, then per-row check on responding_to_review_id) — fine
# at dev scale, expensive when the table reaches O(100k) rows.
#
# A partial index on (triage_status, created_at) WHERE the row is a
# top-level comment shrinks index size to ~5-10% of the table while
# matching the query's exact shape. created_at is included so the
# DESC order avoids a sort.
#
# disable_ddl_transaction! + algorithm: :concurrently — same canonical
# pattern as the lifecycle index migration (.2 work). No ACCESS EXCLUSIVE
# during the build.
#
# if_not_exists: true — idempotent across deploys where someone may have
# manually added the same index.
class AddTopLevelTriagePartialIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :reviews,
              %i[triage_status created_at],
              where: "action = 'comment' AND responding_to_review_id IS NULL",
              name: 'idx_reviews_top_level_triage_recent',
              algorithm: :concurrently,
              if_not_exists: true
  end
end
