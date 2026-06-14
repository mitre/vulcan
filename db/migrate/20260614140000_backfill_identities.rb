# frozen_string_literal: true

class BackfillIdentities < ActiveRecord::Migration[8.0]
  def up
    User.where.not(provider: nil).where.not(uid: nil).find_each do |user|
      Identity.find_or_create_by!(provider: user.provider, uid: user.uid) do |identity|
        identity.user = user
        identity.email = user.email
        identity.last_sign_in_at = user.current_sign_in_at || user.last_sign_in_at
      end
    end
  end

  def down
    Identity.delete_all
  end
end
