class FixIaControlsColumnName < ActiveRecord::Migration[5.1]
  def change
    rename_column :srg_controls, :iacontrols, :nist_families
  end
end
