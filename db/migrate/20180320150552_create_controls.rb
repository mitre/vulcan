class CreateControls < ActiveRecord::Migration[5.1]
  def change
    create_table :controls do |t|
      t.string :title
      t.string :description
      t.float :impact
      t.string :code
      t.string :control_id
      t.string :sl_ref
      t.string :sl_line
      t.text   :tag

      t.timestamps
    end
  end
end
