# frozen_string_literal: true

# PR-717 review remediation .2 — columns + FKs only. Index creation is
# split into a separate concurrent-index migration
# (20260501171000_add_review_lifecycle_indexes_concurrently) so deployment
# does not acquire ACCESS EXCLUSIVE on `reviews` for the duration of all
# five index builds. Pattern: 20260209232046_add_severity_count_indexes_to_base_rules.
class AddLifecycleColumnsToReviews < ActiveRecord::Migration[8.0]
  def change
    change_table :reviews, bulk: true do |t|
      t.string   :triage_status, default: 'pending', null: false
      # values: pending | concur | concur_with_comment | non_concur
      #       | duplicate | informational | needs_clarification | withdrawn

      t.bigint   :triage_set_by_id
      t.datetime :triage_set_at
      t.datetime :adjudicated_at
      t.bigint   :adjudicated_by_id
      t.bigint   :duplicate_of_review_id
      t.bigint   :responding_to_review_id
      t.string   :section
    end

    add_foreign_key :reviews, :users,   column: :triage_set_by_id,        on_delete: :nullify
    add_foreign_key :reviews, :users,   column: :adjudicated_by_id,       on_delete: :nullify
    add_foreign_key :reviews, :reviews, column: :duplicate_of_review_id,  on_delete: :nullify
    add_foreign_key :reviews, :reviews, column: :responding_to_review_id, on_delete: :cascade
  end
end
