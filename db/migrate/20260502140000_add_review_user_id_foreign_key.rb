# frozen_string_literal: true

# PR-717 review remediation .j4a step A3 — pass 1 of 2 (Strong Migrations
# canonical pattern). Adds the FK with `validate: false` so the table
# is not held under ACCESS EXCLUSIVE while existing rows are validated.
# The companion migration (20260502140001) runs `validate_foreign_key`
# inside `disable_ddl_transaction!` to validate without the long lock.
#
# `on_delete: :nullify` mirrors `User has_many :reviews, dependent: :nullify`
# (app/models/user.rb:49). Rails-side nullify still works on
# User#destroy — the FK is the DB-layer safety net for direct SQL
# `DELETE FROM users` (which bypasses Rails callbacks).
#
# Pre-.j4a there was no FK at all on this column, so direct SQL DELETE
# orphaned every review and the next save raised `User must exist`. Step
# A2 made `belongs_to :user, optional: true` so the nullified row is
# valid; original commenter attribution lives on commenter_imported_*
# columns from step A1.
class AddReviewUserIdForeignKey < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :reviews, :users, column: :user_id,
                    on_delete: :nullify, validate: false
  end
end
