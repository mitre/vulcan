# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User lockout (Devise :lockable)' do
  before { Rails.application.reload_routes! }

  # Ensure an admin exists first to prevent first-user-admin promotion
  let!(:admin) { create(:user, admin: true) }

  describe 'devise modules' do
    it 'includes :lockable' do
      expect(User.devise_modules).to include(:lockable)
    end
  end

  describe 'locking after failed attempts' do
    let(:user) { create(:user) }
    let(:max_attempts) { Settings.lockout.maximum_attempts }

    it 'locks the account after maximum failed attempts' do
      max_attempts.times do
        user.valid_for_authentication? { false }
      end

      user.reload
      expect(user.access_locked?).to be true
    end

    it 'tracks failed_attempts count' do
      2.times { user.valid_for_authentication? { false } }

      user.reload
      expect(user.failed_attempts).to eq(2)
    end

    it 'does not lock before reaching maximum attempts' do
      (max_attempts - 1).times do
        user.valid_for_authentication? { false }
      end

      user.reload
      expect(user.access_locked?).to be false
    end
  end

  describe 'unlocking' do
    let(:user) { create(:user) }

    before do
      user.lock_access!(send_instructions: false)
    end

    it 'is locked before unlock' do
      expect(user.access_locked?).to be true
    end

    it 'unlocks via unlock_access!' do
      user.unlock_access!
      expect(user.access_locked?).to be false
    end

    it 'resets failed_attempts on unlock' do
      user.unlock_access!
      user.reload
      expect(user.failed_attempts).to eq(0)
    end

    it 'clears locked_at on unlock' do
      user.unlock_access!
      user.reload
      expect(user.locked_at).to be_nil
    end
  end
end
