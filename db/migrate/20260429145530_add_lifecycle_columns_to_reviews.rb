# frozen_string_literal: true

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

      t.index %i[action triage_status]
      t.index %i[rule_id section triage_status]
      t.index :responding_to_review_id
      t.index :duplicate_of_review_id
    end

    add_index :reviews, :user_id unless index_exists?(:reviews, :user_id)

    add_foreign_key :reviews, :users,   column: :triage_set_by_id,        on_delete: :nullify
    add_foreign_key :reviews, :users,   column: :adjudicated_by_id,       on_delete: :nullify
    add_foreign_key :reviews, :reviews, column: :duplicate_of_review_id,  on_delete: :nullify
    add_foreign_key :reviews, :reviews, column: :responding_to_review_id, on_delete: :cascade
  end
end
