class AddNistToSrgControl < ActiveRecord::Migration[5.1]
  def change
    add_reference :nist_families, :srg_control, foreign_key: true
  end
end
