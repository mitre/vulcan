# frozen_string_literal: true

# Backfills reviews imported via JSON backup before bf86b71 fixed
# ReviewBuilder to set commentable_type/commentable_id. Without these
# columns, paginated_comments filters exclude the rows and they appear
# missing from the triage table even though they exist in the DB.
class BackfillNullCommentableOnReviews < ActiveRecord::Migration[8.0]
  def up
    execute(<<~SQL.squish)
      UPDATE reviews
      SET commentable_type = 'BaseRule', commentable_id = rule_id
      WHERE commentable_id IS NULL AND rule_id IS NOT NULL
    SQL
  end

  def down
    # No-op: backfill is idempotent and data-only
  end
end
