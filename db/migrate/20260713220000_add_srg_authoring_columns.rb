# frozen_string_literal: true

# Storage seam for SRG component authoring (ADR
# docs/decisions/adr-srg-component-authoring.md §8.2, §12.1).
#
# The XOR CHECK ships in the SAME migration that makes an SrgRule's catalog
# parent optional — sequencing them separately opens a window where a catalog
# SrgRule saves with NULL security_requirements_guide_id and no compensating
# constraint (bulk SrgRule.import bypasses model validations).
class AddSrgAuthoringColumns < ActiveRecord::Migration[8.0]
  XOR_CHECK = "type <> 'SrgRule' OR " \
              '((component_id IS NULL) <> (security_requirements_guide_id IS NULL))'

  def up
    add_column :base_rules, :derived_from_srg_rule_id, :bigint
    add_index :base_rules, :derived_from_srg_rule_id
    add_foreign_key :base_rules, :base_rules,
                    column: :derived_from_srg_rule_id, on_delete: :nullify

    # Pre-flight guard: prove no existing SrgRule row is both-NULL or
    # both-set before adding the constraint. Violations abort the migration
    # for a human decision — never auto-repaired.
    violating = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM base_rules
      WHERE type = 'SrgRule'
        AND (component_id IS NULL) = (security_requirements_guide_id IS NULL)
    SQL
    if violating.positive?
      raise "#{violating} SrgRule row(s) violate authored-XOR-catalog — " \
            'resolve them manually before running this migration'
    end

    # Type-scoped: Rule and StigRule rows carry neither/other FKs and must
    # be unaffected by this constraint.
    add_check_constraint :base_rules, XOR_CHECK, name: 'base_rules_srg_authored_xor_catalog'
  end

  def down
    remove_check_constraint :base_rules, name: 'base_rules_srg_authored_xor_catalog'
    remove_foreign_key :base_rules, column: :derived_from_srg_rule_id
    remove_index :base_rules, :derived_from_srg_rule_id
    remove_column :base_rules, :derived_from_srg_rule_id
  end
end
