class CreateHostConfigs < ActiveRecord::Migration[5.1]
  def change
    create_table :host_configs do |t|
      t.string :encrypted_host
      t.string :encrypted_host_iv
      t.string :encrypted_user
      t.string :encrypted_user_iv
      t.string :encrypted_password
      t.string :encrypted_password_iv
      t.string :encrypted_transport_method
      t.string :encrypted_transport_method_iv
      t.string :encrypted_port
      t.string :encrypted_port_iv
      t.integer "user_id"
      t.timestamps
      t.index ["user_id"], name: "index_users_host_configs_on_user_id"
    end
  end
end
