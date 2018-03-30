class AddNistToControl < ActiveRecord::Migration[5.1]
  def change
    add_reference :nist_families, :control, foreign_key: true
  end
end
