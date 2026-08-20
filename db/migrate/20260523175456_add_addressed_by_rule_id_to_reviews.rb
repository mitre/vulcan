# frozen_string_literal: true

class AddAddressedByRuleIdToReviews < ActiveRecord::Migration[8.0]
  def change
    add_reference :reviews, :addressed_by_rule, foreign_key: { to_table: :base_rules, on_delete: :restrict },
                                                null: true
  end
end
