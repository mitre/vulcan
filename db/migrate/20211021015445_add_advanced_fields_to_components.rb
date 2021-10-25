class AddAdvancedFieldsToComponents < ActiveRecord::Migration[6.1]
  def change
    add_column :components, :advanced_fields, :boolean, default: false
  end
end
