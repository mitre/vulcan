class CreateNistFamilies < ActiveRecord::Migration[5.1]
  def change
    create_table :nist_families do |t|
      t.string :family
      t.integer :version

      t.timestamps
    end
  end
end
