class AddDescriptionToRules < ActiveRecord::Migration[6.1]
  def change
    add_column :rules, :description, :text, default: ''
  end
end
