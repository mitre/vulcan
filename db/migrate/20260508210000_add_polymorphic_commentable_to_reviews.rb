# frozen_string_literal: true

# Adds polymorphic commentable_type/commentable_id columns to reviews
# so a Review can target either a Rule (existing behavior) or a Component
# (new — see issue #725). Backfills existing rule-scoped Reviews so reads
# can switch to the polymorphic columns. NOT NULL constraint is deferred
# to a follow-up migration in v3.x once a deploy has confirmed data is
# consistent and no orphan reviews exist.
class AddPolymorphicCommentableToReviews < ActiveRecord::Migration[8.0]
  def up
    add_reference :reviews, :commentable, polymorphic: true, null: true, index: true

    # Backfill: every existing review is rule-scoped. Single SQL UPDATE — no
    # application model reference (avoids future-deploy fragility), no batching
    # (postgres handles the row count fine for a single column-copy UPDATE).
    execute(<<~SQL.squish)
      UPDATE reviews
      SET commentable_type = 'BaseRule', commentable_id = rule_id
      WHERE commentable_id IS NULL AND rule_id IS NOT NULL
    SQL
  end

  def down
    remove_reference :reviews, :commentable, polymorphic: true, index: true
  end
end
