class CreateProjectMembers < ActiveRecord::Migration[6.1]
  def change
    create_table :project_members do |t|
      t.references :user, foreign_key: true
      t.references :project, foreign_key: true
      t.string :role, null: false, default: 'editor'
      t.timestamps
    end
    add_index :project_members, [ :user_id, :project_id ], unique: true,  name: 'by_user_and_project'
  end
end
