# frozen_string_literal: true

# PR-717 review remediation .j4a step A4 — pass 2 of 2 (Strong Migrations
# canonical pattern). Validates the FK added in 20260502150000 outside a
# DDL transaction so existing-row validation does not hold ACCESS
# EXCLUSIVE on `reviews` for the duration of the scan.
#
# Orphan handling (different shape than the user_id step A3 pair):
# `reviews.rule_id` references `base_rules.id`. Orphans here would mean
# a review pointing at a deleted base_rule — those rows can never be
# rebuilt (no canonical "deleted rule attribution" pattern in Vulcan,
# unlike user_id which has commenter_imported_*). Best-effort policy:
# delete (not nullify) any orphan reviews. The data is unrecoverable
# either way; deleting them keeps the FK validation clean.
#
# In practice no orphans should exist — the existing hard-delete path
# in app/controllers/components_controller.rb:146-153 deletes reviews
# BEFORE rules. The cleanup here is defensive in case a non-Rails
# operation (manual SQL, prior bug) left orphans behind.
class ValidateReviewRuleIdForeignKey < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      DELETE FROM reviews
       WHERE rule_id IS NOT NULL
         AND NOT EXISTS (SELECT 1 FROM base_rules WHERE base_rules.id = reviews.rule_id)
    SQL
    validate_foreign_key :reviews, column: :rule_id
  end

  def down
    # FK existence + validity isn't reversible without removing the FK
    # itself — that's the responsibility of the up-pair migration's
    # rollback. No-op here.
  end
end
