class CreateSrgControls < ActiveRecord::Migration[5.1]
  def change
    create_table :srg_controls do |t|
      t.string :controlId
      t.string :severity
      t.string :title
      t.string :description
      t.string :iacontrols
      t.string :ruleID
      t.string :fixid
      t.string :fixtext
      t.string :checkid
      t.string :checktext

      t.timestamps
    end
  end
end
