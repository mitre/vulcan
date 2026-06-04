# frozen_string_literal: true

class AddReviewFkCheckConstraints < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :reviews, "triage_status = 'duplicate' OR duplicate_of_review_id IS NULL",
                         name: 'chk_review_duplicate_fk_consistency'

    add_check_constraint :reviews, "triage_status = 'addressed_by' OR addressed_by_rule_id IS NULL",
                         name: 'chk_review_addressed_by_fk_consistency'
  end
end
