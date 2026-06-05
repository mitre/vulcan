# frozen_string_literal: true

# v2-480.13 / expert review finding F2 — pass 2 of 2 (Strong Migrations
# canonical pattern). Validates the FKs added in 20260605142102 outside
# a DDL transaction so existing-row validation does not hold ACCESS
# EXCLUSIVE on rule_satisfactions for the duration of the scan.
#
# Orphan handling: any row whose rule_id or satisfied_by_rule_id
# references a non-existent base_rule is unrecoverable (there is no
# canonical "deleted rule attribution" pattern for satisfactions —
# the relation is binary, no metadata). Best-effort policy: delete.
# In practice no orphans should exist on a clean instance — Rule's
# HABTM cleanup runs as part of the dependent: :destroy chain when a
# rule is deleted via Rails. The cleanup here is defensive against
# non-Rails operations (manual SQL, prior bug, raw bulk imports)
# leaving orphans behind.
class ValidateRuleSatisfactionsForeignKeys < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      DELETE FROM rule_satisfactions
       WHERE NOT EXISTS (SELECT 1 FROM base_rules WHERE base_rules.id = rule_satisfactions.rule_id)
          OR NOT EXISTS (SELECT 1 FROM base_rules WHERE base_rules.id = rule_satisfactions.satisfied_by_rule_id)
    SQL
    validate_foreign_key :rule_satisfactions, column: :rule_id
    validate_foreign_key :rule_satisfactions, column: :satisfied_by_rule_id
  end

  def down
    # FK existence + validity isn't reversible without removing the FK
    # itself — that's the responsibility of the up-pair migration's
    # rollback. No-op here.
  end
end
