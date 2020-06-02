# frozen_string_literal: true

# This is our main user model, local, LDAP, and omniauth users are all stored here.
# We store provider and UID from the Omniauth provider that is logging a user in.
class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :rememberable, :recoverable, :confirmable, :trackable, :validatable

  devise :omniauthable, omniauth_providers: Devise.omniauth_providers

  validates :name, :password, presence: true

  before_create :skip_confirmation!, unless: -> { Settings.local_login.email_confirmation }

  def self.from_omniauth(auth)
    find_or_create_by(email: auth.info.email) do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 50]
      user.name = auth.info.name || "#{auth.provider} user"
      user.provider = auth.provider
      user.uid = auth.uid

      user.skip_confirmation!
    end
  end
end
