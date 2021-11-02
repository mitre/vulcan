class CreateComponentMetadataTable < ActiveRecord::Migration[6.1]
  def change
    create_table :component_metadata do |t|
      t.json :data, null: false
      t.bigint :component_id
      t.timestamps
    end
    add_index :component_metadata, [:component_id], unique: true,  name: 'by_component_id'
  end
end
