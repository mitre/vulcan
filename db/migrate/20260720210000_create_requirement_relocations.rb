# frozen_string_literal: true

# Relocation is a first-class record, never a status: a pending row IS the
# move marker for an authored requirement, and an executed row is the
# lifecycle fact that it moved out. The source-side FK stays restrictive at
# the database (the source rule's has_many cascades via dependent: :destroy);
# the target side nullifies so destroying a landed requirement leaves the
# history row with an audit trail rather than blocking the destroy.
class CreateRequirementRelocations < ActiveRecord::Migration[8.0]
  def change
    create_table :requirement_relocations do |t|
      t.references :source_rule, null: false, foreign_key: { to_table: :base_rules }
      t.string :target_technology_token, null: false
      t.references :target_rule, foreign_key: { to_table: :base_rules, on_delete: :nullify }
      # Marker provenance survives account removal: nullify, never cascade.
      t.references :requested_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :executed_at

      t.timestamps
    end

    # One pending marker per source requirement; executed history is
    # unbounded.
    add_index :requirement_relocations, :source_rule_id, unique: true,
                                                         where: 'executed_at IS NULL',
                                                         name: 'index_requirement_relocations_pending_source'
    # The per-family backlog query: pending markers by destination token.
    add_index :requirement_relocations, :target_technology_token
  end
end
