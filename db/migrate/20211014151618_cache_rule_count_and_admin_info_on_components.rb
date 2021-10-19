class CacheRuleCountAndAdminInfoOnComponents < ActiveRecord::Migration[6.1]
  def change
    add_column :components, :rules_count, :integer, default: 0
    add_column :components, :admin_name, :string
    add_column :components, :admin_email, :string
    add_column :projects, :admin_name, :string
    add_column :projects, :admin_email, :string
  end
end
