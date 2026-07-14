# frozen_string_literal: true

# Authoring-profile discriminator for components (ADR
# docs/decisions/adr-srg-component-authoring.md §3, §12.1). Every existing
# component authors a STIG, so the default backfills 'stig'. Immutability
# after create is enforced at the model layer.
class AddDocumentTypeToComponents < ActiveRecord::Migration[8.0]
  def change
    add_column :components, :document_type, :string, null: false, default: 'stig'
  end
end
