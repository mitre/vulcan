# frozen_string_literal: true

# Multi-parent derivation: a component derives from 1..N SRG parents. The join
# table carries the full parent set; `based_on`
# (components.security_requirements_guide_id) stays the primary parent.
#
# Backfill and the NOT NULL constraint are separate, ordered migrations so each
# step stays lock-safe (strong_migrations). The join model, associations, and
# the "based_on in join, >=1 parent" invariant are the sibling card — this is
# schema only.
class CreateComponentSourceSrgs < ActiveRecord::Migration[8.0]
  def change
    create_table :component_source_srgs do |t|
      # A join row is owned by its component — cascade its removal. Restrict on
      # the parent side: an SRG that is still a parent cannot be deleted out
      # from under a component (protects the >=1-parent invariant).
      t.references :component, null: false, foreign_key: { on_delete: :cascade }
      t.references :security_requirements_guide, null: false, foreign_key: true

      t.timestamps
    end
    add_index :component_source_srgs,
              %i[component_id security_requirements_guide_id],
              unique: true,
              name: 'index_component_source_srgs_on_component_and_srg'
  end
end
