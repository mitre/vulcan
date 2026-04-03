# frozen_string_literal: true

require 'rails_helper'
require 'bcrypt'

RSpec.describe 'PBKDF2-SHA512 password hashing' do
  before do
    Rails.application.reload_routes!
  end

  let(:password) { 'S3cure!#Pass001' }

  describe 'Pbkdf2Sha512 encryptor' do
    let(:encryptor) { Devise::Encryptable::Encryptors::Pbkdf2Sha512 }
    let(:salt) { SecureRandom.random_bytes(32) }
    let(:stretches) { 1 }
    let(:pepper) { Devise.pepper }

    it 'produces a self-describing hash format' do
      hash = encryptor.digest(password, stretches, salt, pepper)
      expect(hash).to start_with('$pbkdf2-sha512$')
    end

    it 'verifies correct passwords' do
      hash = encryptor.digest(password, stretches, salt, pepper)
      expect(encryptor.compare(hash, password, stretches, salt, pepper)).to be true
    end

    it 'rejects incorrect passwords' do
      hash = encryptor.digest(password, stretches, salt, pepper)
      expect(encryptor.compare(hash, 'WrongPassword!1', stretches, salt, pepper)).to be false
    end

    it 'produces different hashes for different passwords' do
      hash1 = encryptor.digest(password, stretches, salt, pepper)
      hash2 = encryptor.digest('OtherP@ss12345!', stretches, salt, pepper)
      expect(hash1).not_to eq(hash2)
    end
  end

  describe 'User authentication with PBKDF2' do
    let(:user) { create(:user, password: password) }

    it 'authenticates with correct password' do
      expect(user.valid_password?(password)).to be true
    end

    it 'rejects incorrect password' do
      expect(user.valid_password?('WrongPassword!1')).to be false
    end

    it 'stores password in PBKDF2 format for new users' do
      expect(user.encrypted_password).to start_with('$pbkdf2-sha512$')
    end
  end

  describe 'bcrypt to PBKDF2 migration' do
    let(:user) { create(:user, password: password) }

    it 'migrates bcrypt passwords on successful login' do
      # Manually set a bcrypt password to simulate pre-migration state
      bcrypt_hash = BCrypt::Password.create(password, cost: 4)
      user.update_column(:encrypted_password, bcrypt_hash)
      user.reload

      expect(user.encrypted_password).to start_with('$2a$')

      # Login should succeed and migrate the password
      expect(user.valid_password?(password)).to be true

      user.reload
      expect(user.encrypted_password).to start_with('$pbkdf2-sha512$')
    end

    it 'does not migrate on failed login' do
      bcrypt_hash = BCrypt::Password.create(password, cost: 4)
      user.update_column(:encrypted_password, bcrypt_hash)
      user.reload

      user.valid_password?('WrongPassword!1')

      user.reload
      expect(user.encrypted_password).to start_with('$2a$')
    end
  end
end
