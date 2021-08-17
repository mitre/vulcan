class CreateProjectMetadataTable < ActiveRecord::Migration[6.1]
  def change
    create_table :project_metadata do |t|
      t.json :data, null: false
      t.bigint :project_id
      t.timestamps
    end
    add_index :project_metadata, [:project_id], unique: true,  name: 'by_project_id'
  end
end
