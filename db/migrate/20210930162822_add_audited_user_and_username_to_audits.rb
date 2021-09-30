class AddAuditedUserAndUsernameToAudits < ActiveRecord::Migration[6.1]
  def change
    add_column :audits, :audited_user_id, :integer
    add_column :audits, :audited_username, :string
  end
end
