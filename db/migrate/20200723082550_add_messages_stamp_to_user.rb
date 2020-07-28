class AddMessagesStampToUser < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :messages_stamp, :datetime, :null => false, :default => Time.at(0)
  end
end
