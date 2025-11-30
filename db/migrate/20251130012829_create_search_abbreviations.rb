class CreateSearchAbbreviations < ActiveRecord::Migration[8.0]
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
