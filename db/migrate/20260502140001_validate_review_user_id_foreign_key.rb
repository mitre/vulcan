# frozen_string_literal: true

# PR-717 review remediation .j4a step A3 — pass 2 of 2 (Strong Migrations
# canonical pattern). Validates the FK added in 20260502140000 outside a
# DDL transaction so existing-row validation does not hold ACCESS
# EXCLUSIVE on `reviews` for the duration of the scan.
#
# Backfill safety net: NULL any orphan user_ids that would fail FK
# validation (rows whose user_id no longer exists in users — possible if
# users were deleted via direct SQL before this FK landed). The orphans
# get the same end-state they'd have post-FK once the User is destroyed
# (user_id=NULL); commenter_imported_* attribution is intentionally NOT
# back-populated here since we don't know who the original commenter
# was — operators who care can reconstruct from audit history if needed.
class ValidateReviewUserIdForeignKey < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      UPDATE reviews
         SET user_id = NULL
       WHERE user_id IS NOT NULL
         AND NOT EXISTS (SELECT 1 FROM users WHERE users.id = reviews.user_id)
    SQL
    validate_foreign_key :reviews, column: :user_id
  end

  def down
    # FK existence + validity isn't reversible without removing the FK
    # itself — that's the responsibility of the up-pair migration's
    # rollback. No-op here.
  end
end
