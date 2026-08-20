# frozen_string_literal: true

# Pass 2 of 2 (Strong Migrations canonical pattern).
# Validates the CHECK constraints added in 20260604185410 outside
# a DDL transaction so existing-row validation does not hold
# ACCESS EXCLUSIVE on `reviews` for the duration of the scan.
class ValidateReviewFkCheckConstraints < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    validate_check_constraint :reviews, name: 'chk_review_duplicate_fk_consistency'
    validate_check_constraint :reviews, name: 'chk_review_addressed_by_fk_consistency'
  end

  def down
    # Validation state is not independently reversible — the up-pair
    # migration's rollback removes the constraints entirely.
  end
end
