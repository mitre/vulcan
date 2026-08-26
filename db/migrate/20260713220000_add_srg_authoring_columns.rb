# frozen_string_literal: true

# Storage seam for SRG component authoring.
#
# The XOR CHECK ships in the SAME migration that makes an SrgRule's catalog
# parent optional — sequencing them separately opens a window where a catalog
# SrgRule saves with NULL security_requirements_guide_id and no compensating
# constraint (bulk SrgRule.import bypasses model validations).
#
# strong_migrations-safe: the index is built concurrently, and the foreign key
# and check constraint are added UNVALIDATED — which still enforces both for
# every new and modified row immediately, keeping the write window the comment
# above guards closed — then validated against existing rows in a separate,
# non-blocking step. disable_ddl_transaction! (required for the concurrent
# index) removes the outer transaction, so every step uses if_(not_)exists to
# stay re-runnable should the release phase retry after a mid-migration failure.
class AddSrgAuthoringColumns < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  XOR_CHECK = "type <> 'SrgRule' OR " \
              '((component_id IS NULL) <> (security_requirements_guide_id IS NULL))'

  CONSTRAINT_NAME = 'base_rules_srg_authored_xor_catalog'

  def up
    # Pre-flight guard BEFORE any DDL: prove no existing SrgRule row is both-NULL
    # or both-set. Violations abort for a human decision — never auto-repaired —
    # and, running first, leave the schema untouched.
    violating = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM base_rules
      WHERE type = 'SrgRule'
        AND (component_id IS NULL) = (security_requirements_guide_id IS NULL)
    SQL
    if violating.positive?
      raise "#{violating} SrgRule row(s) violate authored-XOR-catalog — " \
            'resolve them manually before running this migration'
    end

    # Nullable, no default — safe.
    add_column :base_rules, :derived_from_srg_rule_id, :bigint, if_not_exists: true

    add_index :base_rules, :derived_from_srg_rule_id, algorithm: :concurrently, if_not_exists: true

    # Added unvalidated (no full-table lock while every row is checked), then
    # validated against existing rows in the non-blocking step that follows.
    add_foreign_key :base_rules, :base_rules, column: :derived_from_srg_rule_id, on_delete: :nullify, validate: false, if_not_exists: true
    validate_foreign_key :base_rules, column: :derived_from_srg_rule_id

    # Type-scoped: Rule and StigRule rows carry neither/other FKs and must be
    # unaffected. Added unvalidated then validated — the pre-flight guard above
    # has already proven existing rows clean.
    add_check_constraint :base_rules, XOR_CHECK, name: CONSTRAINT_NAME, validate: false, if_not_exists: true
    validate_check_constraint :base_rules, name: CONSTRAINT_NAME
  end

  def down
    remove_check_constraint :base_rules, name: CONSTRAINT_NAME, if_exists: true
    remove_foreign_key :base_rules, column: :derived_from_srg_rule_id, if_exists: true
    remove_index :base_rules, column: :derived_from_srg_rule_id, algorithm: :concurrently, if_exists: true
    remove_column :base_rules, :derived_from_srg_rule_id, if_exists: true
  end
end
