class CreateProfiles < ActiveRecord::Migration[5.1]
  def change
    create_table :profiles do |t|
      t.string :name
      t.string :title
      t.string :maintainer
      t.string :copyright
      t.string :copyright_email
      t.string :license
      t.string :summary
      t.string :version
      t.string :sha256

      t.timestamps
    end
  end
end
