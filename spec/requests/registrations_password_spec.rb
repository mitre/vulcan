# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Registration password validation' do
  before do
    Rails.application.reload_routes!
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

  describe 'POST /users (registration)' do
    it 'rejects a weak password' do
      configure_password
      post user_registration_path, params: {
        user: {
          name: 'Test User',
          email: 'newuser@example.com',
          password: 'weak',
          password_confirmation: 'weak'
        }
      }
      expect(User.find_by(email: 'newuser@example.com')).to be_nil
    end

    it 'accepts a strong password meeting DoD 2222 policy' do
      configure_password
      post user_registration_path, params: {
        user: {
          name: 'Test User',
          email: 'stronguser@example.com',
          password: 'AAbbc12!@defghi',
          password_confirmation: 'AAbbc12!@defghi'
        }
      }
      expect(User.find_by(email: 'stronguser@example.com')).to be_present
    end
  end
end
