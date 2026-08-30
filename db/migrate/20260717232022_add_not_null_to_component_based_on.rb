# frozen_string_literal: true

# Establish NOT NULL on the primary-parent column via the lock-safe 2-pass
# pattern: add a NOT VALID check constraint (instant, no scan), validate it
# outside a DDL transaction (short lock), then set NOT NULL — Postgres reuses
# the validated constraint instead of a full table scan — and drop the now
# redundant check. Validation raises if any component still has a NULL
# based_on, so this fails closed rather than fabricating or dropping a parent.
#
# Every step is re-runnable. disable_ddl_transaction! means a failure part-way
# leaves the earlier steps committed while the migration stays unrecorded in
# schema_migrations, so a retry replays them: without the existence guards, the
# rerun after a validation failure dies on PG::DuplicateObject instead of
# resuming. validate_check_constraint and change_column_null are already no-ops
# when their work is done. Matches AddSrgAuthoringColumns (20260713220000).
class AddNotNullToComponentBasedOn < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  CONSTRAINT = 'components_security_requirements_guide_id_null'

  def up
    add_check_constraint :components, 'security_requirements_guide_id IS NOT NULL',
                         name: CONSTRAINT, validate: false, if_not_exists: true
    validate_check_constraint :components, name: CONSTRAINT
    change_column_null :components, :security_requirements_guide_id, false
    remove_check_constraint :components, name: CONSTRAINT, if_exists: true
  end

  def down
    change_column_null :components, :security_requirements_guide_id, true
  end
end
