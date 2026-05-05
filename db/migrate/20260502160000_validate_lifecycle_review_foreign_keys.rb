# frozen_string_literal: true

# PR-717 review remediation .2kp — companion to 20260429145530's pivot
# to Strong Migrations 2-pass FK adds. Validates the 3 lifecycle FKs
# outside a DDL transaction so existing-row validation does not hold
# ACCESS EXCLUSIVE on `reviews` for the duration of the scan.
#
# responding_to_review_id is NOT in this migration — the .4 fix
# (20260502080000_change_review_responding_to_fk_to_restrict) drops +
# re-adds that FK with its own paired validate_foreign_key.
#
# validate_foreign_key is idempotent: on existing dev/test DBs where the
# original migration already ran with the eager-validate shape, this is
# a no-op (PG: validating an already-VALID FK does nothing).
class ValidateLifecycleReviewForeignKeys < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    validate_foreign_key :reviews, column: :triage_set_by_id
    validate_foreign_key :reviews, column: :adjudicated_by_id
    validate_foreign_key :reviews, column: :duplicate_of_review_id
  end

  def down
    # FK validity isn't reversible without removing the FK itself —
    # that's the responsibility of the up-pair migration's rollback.
    # No-op here.
  end
end
