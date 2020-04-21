class AddVersionAndReleaseToSrg < ActiveRecord::Migration[5.1]
  def change
    add_column :srgs, :release, :string
    add_column :srgs, :version, :integer
  end
end
