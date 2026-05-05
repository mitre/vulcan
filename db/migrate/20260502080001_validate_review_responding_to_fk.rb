# frozen_string_literal: true

# PR-717 review remediation .kea — paired validate half of the
# 2-pass FK pattern from 20260502080000_change_review_responding_to_fk_to_restrict.
#
# Pre-fix the .4 migration ran add_foreign_key (validate: false) AND
# validate_foreign_key in the same DDL transaction. On a production-
# sized reviews table the validate scan holds ACCESS EXCLUSIVE on
# `reviews` for the duration — write-blocking window.
#
# This migration runs the validate alone, with disable_ddl_transaction!
# so Postgres acquires only short SHARE ROW EXCLUSIVE locks per
# affected page. Matches the 2kp pattern already used for the lifecycle
# FKs (20260502160000_validate_lifecycle_review_foreign_keys).
#
# Idempotent: validate_foreign_key on an already-VALID FK is a no-op
# in Postgres. Safe to re-run on dev/test DBs that previously ran the
# eager-validate shape.
class ValidateReviewRespondingToFk < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    validate_foreign_key :reviews, column: :responding_to_review_id
  end

  def down
    # FK validity isn't reversible without removing the FK itself —
    # that's the responsibility of the up-pair migration's rollback.
    # No-op here.
  end
end
