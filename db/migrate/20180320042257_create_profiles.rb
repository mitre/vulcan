class CreateProfiles < ActiveRecord::Migration[5.1]
  def change
    create_table :projects do |t|
      t.string "name"
      t.string "title"
      t.string "maintainer"
      t.string "copyright"
      t.string "copyright_email"
      t.string "license"
      t.string "summary"
      t.string "version"
    end
  end
end
