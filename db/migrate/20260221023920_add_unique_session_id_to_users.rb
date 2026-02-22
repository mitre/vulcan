class AddUniqueSessionIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :unique_session_id, :string
  end
end
