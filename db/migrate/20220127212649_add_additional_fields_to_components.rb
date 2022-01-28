class AddAdditionalFieldsToComponents < ActiveRecord::Migration[6.1]
  def change
    rename_column :components, :version, :name

    add_column :components, :release_version, :integer
    add_column :components, :release_revision, :integer
    add_column :components, :description, :text
  end
end
