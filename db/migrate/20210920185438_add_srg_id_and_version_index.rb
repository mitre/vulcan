class AddSrgIdAndVersionIndex < ActiveRecord::Migration[6.1]
  def change
    add_index :security_requirements_guides, [:srg_id, :version], name: 'security_requirements_guides_id_and_version', unique: true
  end
end
