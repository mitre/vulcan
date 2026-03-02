# frozen_string_literal: true

class AddNameToSecurityRequirementsGuide < ActiveRecord::Migration[6.1]
  def change
    add_column :security_requirements_guides, :name, :string
  end
end
