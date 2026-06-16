# frozen_string_literal: true

# Expert review finding F2 — pass 1 of 2 (Strong Migrations
# canonical pattern). Adds FK constraints to rule_satisfactions on both
# join-column directions with `validate: false`, so the table is not
# held under ACCESS EXCLUSIVE while existing rows are checked. The
# companion migration (20260605142103) runs `validate_foreign_key`
# inside `disable_ddl_transaction!` to validate without the long lock.
#
# The table was created in 20211103190520_create_rule_satisfactions
# without any DB-level FK constraints. A satisfaction row referencing
# a non-existent rule on either side could persist as a dangling
# bigint — silently mis-routed during component sync merge.
#
# on_delete: :cascade (different from reviews — see
# vulcan-cascade-rails-owns memory): rule_satisfactions is a HABTM
# join table modeled with an empty RuleSatisfaction < ApplicationRecord
# stub. There are no Rails callbacks and no audited gem hooks to
# preserve — the table records relationship existence only. When
# either parent rule disappears, the relation row is meaningless and
# should be removed at the DB level too. Belt and suspenders alongside
# Rails' HABTM cleanup.
class AddRuleSatisfactionsForeignKeys < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :rule_satisfactions, :base_rules,
                    column: :rule_id,
                    on_delete: :cascade,
                    validate: false
    add_foreign_key :rule_satisfactions, :base_rules,
                    column: :satisfied_by_rule_id,
                    on_delete: :cascade,
                    validate: false
  end
end
