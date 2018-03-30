class AddExtraColumns < ActiveRecord::Migration[5.1]
  def change
    add_column :controls, :checktext, :text
    add_column :controls, :fixtext, :text
    add_column :controls, :justification, :text
    add_column :controls, :status, :text
  end
end
