# frozen_string_literal: true

# PR-717 review remediation .2 — concurrent index pass for the lifecycle
# columns added in 20260429145530. Splitting the index creation away from
# the column-add migration avoids ACCESS EXCLUSIVE on `reviews` for the
# duration of five index builds. Pattern matches
# 20260209232046_add_severity_count_indexes_to_base_rules.
#
# `if_not_exists: true` makes this a no-op on instances where the prior
# (pre-split) form of 20260429145530 already created the indexes.
class AddReviewLifecycleIndexesConcurrently < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_index :reviews, %i[action triage_status],
              algorithm: :concurrently, if_not_exists: true
    add_index :reviews, %i[rule_id section triage_status],
              algorithm: :concurrently, if_not_exists: true
    add_index :reviews, :responding_to_review_id,
              algorithm: :concurrently, if_not_exists: true
    add_index :reviews, :duplicate_of_review_id,
              algorithm: :concurrently, if_not_exists: true
    add_index :reviews, :user_id,
              algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :reviews, %i[action triage_status], if_exists: true
    remove_index :reviews, %i[rule_id section triage_status], if_exists: true
    remove_index :reviews, :responding_to_review_id, if_exists: true
    remove_index :reviews, :duplicate_of_review_id, if_exists: true
    remove_index :reviews, :user_id, if_exists: true
  end
end
