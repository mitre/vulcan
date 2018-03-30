class AddSrgIdToControl < ActiveRecord::Migration[5.1]
  def change
    add_column :controls, :srg_id, :text
  end
end
