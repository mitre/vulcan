# frozen_string_literal: true

# `core` marks the three non-public core SRGs (SRG-NET / SRG-OS / SRG-APP
# namespaces) that are not on cyber.mil and enter Vulcan via upload. Derived
# (public) SRGs and every existing row are non-core — hence default false.
# The flag is set on core-document upload (sibling work); this is the column.
class AddCoreToSecurityRequirementsGuides < ActiveRecord::Migration[8.0]
  def change
    add_column :security_requirements_guides, :core, :boolean, default: false, null: false
  end
end
