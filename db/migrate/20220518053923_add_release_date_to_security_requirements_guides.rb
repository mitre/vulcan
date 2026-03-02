# frozen_string_literal: true

class AddReleaseDateToSecurityRequirementsGuides < ActiveRecord::Migration[6.1]
  def change
    add_column :security_requirements_guides, :release_date, :date
  end
end
