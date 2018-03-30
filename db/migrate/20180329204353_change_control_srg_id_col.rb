class ChangeControlSrgIdCol < ActiveRecord::Migration[5.1]
  def change
    rename_column :controls, :srg_id, :srg_title_id
  end
end
