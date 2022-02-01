class AddAdditionalFieldsToComponents < ActiveRecord::Migration[6.1]
  def change
    rename_column :components, :version, :name

    add_column :components, :version, :integer
    add_column :components, :release, :integer
    add_column :components, :title, :string
    add_column :components, :description, :text
  end
end
