class CreateProjectAccessRequests < ActiveRecord::Migration[6.1]
  def change
    create_table :project_access_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end

    add_index :project_access_requests, [:user_id, :project_id], unique: true
  end
end
