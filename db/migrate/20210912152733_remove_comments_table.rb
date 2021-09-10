class RemoveCommentsTable < ActiveRecord::Migration[6.1]
  def change
    drop_table :comments
  end
end
