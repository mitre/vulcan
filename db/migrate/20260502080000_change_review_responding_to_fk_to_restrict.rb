# frozen_string_literal: true

# PR-717 review remediation .4 F1 — Rails owns the cascade for Review#responses;
# Postgres FK becomes a safety net via on_delete: :restrict.
#
# Why: the original FK on_delete: :cascade combined with Rails
# `dependent: :destroy` is the canonical "double-cascade" anti-pattern.
# When Postgres cascades it skips Rails callbacks → audited gem doesn't
# capture per-Review destroy events → the audit-trail recoverability
# work in `c92fc83` (associated_with: :rule) doesn't deliver because
# the per-row destroy audits never get written. With FK :restrict,
# any deleter must go through Rails (or explicitly delete children
# first), which guarantees the callback path fires.
#
# Strong Migrations 2-pass: validate: false on the new FK + separate
# validate_foreign_key avoids the ACCESS EXCLUSIVE on `reviews` for
# the duration of validation on production-sized tables.
#
# Reversible: down restores the legacy :cascade semantics. WARNING:
# do NOT run down in production after admin_destroy snapshots are
# relied on — silent SQL cascades will skip the audited callback path.
class ChangeReviewRespondingToFkToRestrict < ActiveRecord::Migration[8.0]
  def up
    remove_foreign_key :reviews, column: :responding_to_review_id
    add_foreign_key :reviews, :reviews,
                    column: :responding_to_review_id,
                    on_delete: :restrict,
                    validate: false
    validate_foreign_key :reviews, column: :responding_to_review_id
  end

  def down
    # WARNING: restoring :cascade re-introduces the audit-trail gap on
    # admin_destroy. Only run in dev for migration round-trip tests.
    remove_foreign_key :reviews, column: :responding_to_review_id
    add_foreign_key :reviews, :reviews,
                    column: :responding_to_review_id,
                    on_delete: :cascade
  end
end
