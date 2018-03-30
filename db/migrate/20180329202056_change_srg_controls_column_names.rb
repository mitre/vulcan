class ChangeSrgControlsColumnNames < ActiveRecord::Migration[5.1]
  def change
    add_column :srg_controls, :srg_title_id, :text
  end
end
