# frozen_string_literal: true

class AddNewProjectColumnsToProject < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :security_requirements_guide_id, :bigint
    add_column :projects, :prefix, :string
  end
end
