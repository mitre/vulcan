# frozen_string_literal: true

class CreatePersonalAccessTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :personal_access_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string     :name,         null: false
      t.string     :token_digest, null: false
      t.string     :token_prefix, limit: 12
      t.text       :scopes,       null: false, default: '[]'
      t.date       :expires_at
      t.datetime   :last_used_at
      t.datetime   :revoked_at
      t.text       :allowed_ips

      t.timestamps
    end

    add_index :personal_access_tokens, :token_digest, unique: true
    add_index :personal_access_tokens, %i[user_id revoked_at], name: 'index_pats_on_user_id_and_active'
  end
end
