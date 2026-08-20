# frozen_string_literal: true

class CreateIdentities < ActiveRecord::Migration[8.0]
  def change
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email
      t.datetime :last_sign_in_at

      t.timestamps
    end

    add_index :identities, %i[provider uid], unique: true
  end
end
