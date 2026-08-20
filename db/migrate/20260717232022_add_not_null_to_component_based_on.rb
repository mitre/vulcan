# frozen_string_literal: true

# Establish NOT NULL on the primary-parent column via the lock-safe 2-pass
# pattern: add a NOT VALID check constraint (instant, no scan), validate it
# outside a DDL transaction (short lock), then set NOT NULL — Postgres reuses
# the validated constraint instead of a full table scan — and drop the now
# redundant check. Validation raises if any component still has a NULL
# based_on, so this fails closed rather than fabricating or dropping a parent.
class AddNotNullToComponentBasedOn < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  CONSTRAINT = 'components_security_requirements_guide_id_null'

  def up
    add_check_constraint :components, 'security_requirements_guide_id IS NOT NULL',
                         name: CONSTRAINT, validate: false
    validate_check_constraint :components, name: CONSTRAINT
    change_column_null :components, :security_requirements_guide_id, false
    remove_check_constraint :components, name: CONSTRAINT
  end

  def down
    change_column_null :components, :security_requirements_guide_id, true
  end
end
