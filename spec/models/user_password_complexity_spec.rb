# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Password complexity validation' do
  before do
    Rails.application.reload_routes!
  end

  def build_user_with_password(password)
    build(:user, password: password, password_confirmation: password)
  end

  around do |example|
    original_password = Settings['password']&.to_hash&.deep_dup
    example.run
  ensure
    if original_password
      Settings['password'] = Settingslogic.new(original_password)
    elsif Settings.respond_to?(:delete_field)
      Settings.delete_field('password')
    end
  end

  def configure_password(overrides = {})
    defaults = {
      'min_length' => 15,
      'min_uppercase' => 2,
      'min_lowercase' => 2,
      'min_number' => 2,
      'min_special' => 2
    }
    Settings['password'] = Settingslogic.new(defaults.merge(overrides))
  end

  # NOTE: Devise's :validatable registers validates_length_of at boot with
  # Settings.password.min_length (15). Tests must use passwords >= 15 chars
  # for acceptance, < 15 chars for rejection.

  describe 'minimum length' do
    it 'rejects passwords shorter than configured minimum' do
      configure_password
      user = build_user_with_password('AB!!cd12')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include(a_string_matching(/at least 15 characters/i))
    end

    it 'accepts passwords meeting minimum length' do
      configure_password('min_uppercase' => 0, 'min_lowercase' => 0,
                         'min_number' => 0, 'min_special' => 0)
      user = build_user_with_password('a' * 15)
      expect(user).to be_valid
    end
  end

  describe 'uppercase count requirement' do
    it 'rejects passwords with fewer uppercase letters than required' do
      configure_password('min_uppercase' => 2, 'min_lowercase' => 0,
                         'min_number' => 0, 'min_special' => 0)
      user = build_user_with_password('Abcdefghijklmno') # 1 uppercase
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include(a_string_matching(/2 uppercase/i))
    end

    it 'accepts passwords meeting uppercase count' do
      configure_password('min_uppercase' => 2, 'min_lowercase' => 0,
                         'min_number' => 0, 'min_special' => 0)
      user = build_user_with_password('ABcdefghijklmno') # 2 uppercase
      expect(user).to be_valid
    end

    it 'skips validation when min_uppercase is 0' do
      configure_password('min_uppercase' => 0, 'min_lowercase' => 0,
                         'min_number' => 0, 'min_special' => 0)
      user = build_user_with_password('abcdefghijklmno')
      expect(user).to be_valid
    end
  end

  describe 'lowercase count requirement' do
    it 'rejects passwords with fewer lowercase letters than required' do
      configure_password('min_uppercase' => 0, 'min_lowercase' => 2,
                         'min_number' => 0, 'min_special' => 0)
      user = build_user_with_password('ABCDEFGHIJKLMNa') # 1 lowercase
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include(a_string_matching(/2 lowercase/i))
    end
  end

  describe 'number count requirement' do
    it 'rejects passwords with fewer digits than required' do
      configure_password('min_uppercase' => 0, 'min_lowercase' => 0,
                         'min_number' => 2, 'min_special' => 0)
      user = build_user_with_password('abcdefghijklmn1') # 1 digit
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include(a_string_matching(/2 number/i))
    end
  end

  describe 'special character count requirement' do
    it 'rejects passwords with fewer special characters than required' do
      configure_password('min_uppercase' => 0, 'min_lowercase' => 0,
                         'min_number' => 0, 'min_special' => 2)
      user = build_user_with_password('abcdefghijklmn!') # 1 special
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include(a_string_matching(/2 special/i))
    end
  end

  describe 'all rules disabled (length only)' do
    it 'accepts any password meeting length requirement' do
      configure_password('min_uppercase' => 0, 'min_lowercase' => 0,
                         'min_number' => 0, 'min_special' => 0)
      user = build_user_with_password('simplesimplesimp')
      expect(user).to be_valid
    end
  end

  describe 'all rules enabled (DoD 2222 default)' do
    it 'accepts a strong password meeting all requirements' do
      configure_password
      # AA(2up) bb(2low) 12(2num) !@(2spec) + padding = 15 chars
      user = build_user_with_password('AAbbc12!@defghi')
      expect(user).to be_valid
    end

    it 'reports multiple violations at once' do
      configure_password
      user = build_user_with_password('short')
      expect(user).not_to be_valid
      expect(user.errors[:password].size).to be >= 3
    end
  end

  describe 'singular vs plural labels' do
    it 'uses singular when count is 1' do
      configure_password('min_uppercase' => 1, 'min_lowercase' => 0,
                         'min_number' => 0, 'min_special' => 0)
      user = build_user_with_password('abcdefghijklmno') # 0 uppercase
      user.valid?
      expect(user.errors[:password]).to include(a_string_matching(/1 uppercase letter\b/))
    end

    it 'uses plural when count is > 1' do
      configure_password('min_uppercase' => 3, 'min_lowercase' => 0,
                         'min_number' => 0, 'min_special' => 0)
      user = build_user_with_password('Abcdefghijklmno') # 1 uppercase
      user.valid?
      expect(user.errors[:password]).to include(a_string_matching(/3 uppercase letters/))
    end
  end

  describe 'skips validation for OmniAuth users' do
    it 'does not validate complexity when provider is set' do
      configure_password
      user = build(:user, provider: 'oidc', uid: '12345',
                          password: Devise.friendly_token)
      user.skip_confirmation!
      expect(user).to be_valid
    end
  end
end
