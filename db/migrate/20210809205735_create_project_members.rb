class CreateProjectMembers < ActiveRecord::Migration[6.1]
  def change
    create_table :project_members do |t|
      t.references :user, foreign_key: true
      t.references :project, foreign_key: true
      t.string :role, null: false, default: 'editor'
      t.timestamps
    end
  end
end
