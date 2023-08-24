class CreateStigs < ActiveRecord::Migration[6.1]
  def change
    create_table :stigs do |t|
      t.string :stig_id
      t.string :title
      t.text :description
      t.string :version
      t.xml :xml
      t.date :benchmark_date

      t.timestamps
    end
    add_index :stigs, [:stig_id, :version], unique: true, name: "stigs_stig_id_version_index"
  end
end
