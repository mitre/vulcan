# frozen_string_literal: true

# PR-717 review remediation .j4a step A4 — pass 1 of 2 (Strong Migrations
# canonical pattern). Adds the FK with `validate: false` so the table is
# not held under ACCESS EXCLUSIVE while existing rows are validated. The
# companion migration (20260502150001) runs `validate_foreign_key` inside
# `disable_ddl_transaction!` to validate without the long lock.
#
# `on_delete: :restrict` (NOT :cascade — the j4a card description's
# original recommendation): mirrors the .4 cascade-ownership lesson
# (memory `vulcan-cascade-rails-owns`, commit 33b2bea). PG :cascade
# skips Rails callbacks → audited gem doesn't capture per-Review destroy
# events. :restrict forces any deleter through the Rails path
# (`Rule#has_many :reviews, dependent: :destroy` walks children-first;
# by the time DELETE FROM base_rules runs, all child reviews are already
# gone, so :restrict is satisfied).
#
# Verified compatible with the existing hard-delete code path at
# app/controllers/components_controller.rb:146-153, which already
# deletes child reviews via `delete_all` before deleting parent rules.
class AddReviewRuleIdForeignKey < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :reviews, :base_rules, column: :rule_id,
                    on_delete: :restrict, validate: false
  end
end
