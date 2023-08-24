class AddNameToStig < ActiveRecord::Migration[6.1]
  def change
    add_column :stigs, :name, :string
  end
end
