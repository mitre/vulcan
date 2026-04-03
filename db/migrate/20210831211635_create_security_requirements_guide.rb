# frozen_string_literal: true

class CreateSecurityRequirementsGuide < ActiveRecord::Migration[6.1]
  def change
    create_table :security_requirements_guides do |t|
      t.string :srg_id, null: false
      t.string :title, null: false
      t.string :version, null: false
      t.xml :xml, null: false
      t.timestamps
    end
  end
end
