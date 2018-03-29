class AddSrgsToProfiles < ActiveRecord::Migration[5.1]
  def change
    add_column :profiles, :srg_ids, :has_many
  end
end
