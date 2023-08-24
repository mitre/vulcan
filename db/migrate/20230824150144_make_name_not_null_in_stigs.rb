class MakeNameNotNullInStigs < ActiveRecord::Migration[6.1]
  def change
    change_column_null :stigs, :name, false
  end
end
