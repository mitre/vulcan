# frozen_string_literal: true

# Receiver-side adjudication on relocation records: acceptance provenance
# (stamped alongside execution) and decline as a retained terminal state
# with required rationale. The one-open-proposal-per-source uniqueness now
# excludes declined rows — a source may be re-proposed after a decline.
class AddAdjudicationToRequirementRelocations < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Safe by inspection: every operation in the block is a nullable
    # column add with no default — each is individually on the checker's
    # safe list; it just cannot see inside a change_table block.
    safety_assured do
      change_table :requirement_relocations, bulk: true do |t|
        t.column :accepted_by_id, :bigint
        t.column :accepted_at, :datetime
        t.column :declined_by_id, :bigint
        t.column :declined_at, :datetime
        t.column :adjudication_rationale, :text
      end
    end

    add_index :requirement_relocations, :accepted_by_id, algorithm: :concurrently
    add_index :requirement_relocations, :declined_by_id, algorithm: :concurrently

    add_foreign_key :requirement_relocations, :users, column: :accepted_by_id,
                                                      on_delete: :nullify, validate: false
    add_foreign_key :requirement_relocations, :users, column: :declined_by_id,
                                                      on_delete: :nullify, validate: false
    validate_foreign_key :requirement_relocations, column: :accepted_by_id
    validate_foreign_key :requirement_relocations, column: :declined_by_id

    remove_index :requirement_relocations, :source_rule_id,
                 unique: true,
                 where: 'executed_at IS NULL',
                 name: :index_requirement_relocations_pending_source,
                 algorithm: :concurrently
    add_index :requirement_relocations, :source_rule_id,
              unique: true,
              where: 'executed_at IS NULL AND declined_at IS NULL',
              name: :index_requirement_relocations_open_proposal,
              algorithm: :concurrently
  end
end
