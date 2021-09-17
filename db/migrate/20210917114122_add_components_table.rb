class AddComponentsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :components do |t|
      t.references :project, index: true
      t.references :child_project, index: true, foreign_key: { to_table: :projects }
      t.timestamps
    end

    add_index :components, [:project_id, :child_project_id], unique: true, name: "components_parent_child_id_index"
  end
end
