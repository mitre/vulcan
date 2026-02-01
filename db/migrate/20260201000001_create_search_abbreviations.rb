# frozen_string_literal: true

##
# Create table for user-defined search abbreviations
# Allows admins to add custom abbreviation expansions beyond the core config
#
class CreateSearchAbbreviations < ActiveRecord::Migration[7.2]
  def change
    create_table :search_abbreviations do |t|
      t.string :abbreviation, null: false
      t.string :expansion, null: false
      t.boolean :active, default: true, null: false
      t.references :created_by, foreign_key: { to_table: :users }, null: true

      t.timestamps
    end

    add_index :search_abbreviations, :abbreviation, unique: true
    add_index :search_abbreviations, :active
  end
end
