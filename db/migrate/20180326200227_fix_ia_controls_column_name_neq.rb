class FixIaControlsColumnNameNeq < ActiveRecord::Migration[5.1]
  def change
    rename_column :srg_controls, :nist_families, :nistFamilies
  end
end
