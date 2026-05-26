# frozen_string_literal: true

# vulcan-v3.x-480.6 §18.4: composite index supporting the comment-count UNION
# query in Project (the hot path on triage/landing pages). The existing
# two-column indexes on (commentable_type, commentable_id) and
# (action, triage_status) don't cover the full predicate; a five-column
# composite lets the planner satisfy the whole WHERE in one scan.
#
# CONCURRENT — production has a live reviews table; building the index
# without ACCESS EXCLUSIVE lock requires disable_ddl_transaction! so Rails
# doesn't wrap the CREATE INDEX in a transaction Postgres can't run
# concurrently inside.
class AddCommentCountCompositeIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :reviews,
              %i[commentable_type commentable_id action triage_status responding_to_review_id],
              name: 'index_reviews_on_commentable_action_triage_responding',
              algorithm: :concurrently
  end
end
