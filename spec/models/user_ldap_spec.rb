# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe '.from_omniauth with LDAP' do
    # Use unique email addresses to avoid conflicts with other tests
    let(:ldap_uid) { 'zoidberg_ldap_test' }
    let(:ldap_email) { "zoidberg_ldap_#{SecureRandom.hex(4)}@planetexpress.com" }
    let(:ldap_name) { 'John A. Zoidberg' }

    def build_auth_hash(email_location: :info, email_value: nil)
      email_value ||= ldap_email

      OmniAuth::AuthHash.new(
        provider: 'ldap',
        uid: ldap_uid,
        info: {
          email: email_location == :info ? email_value : nil,
          name: ldap_name
        },
        extra: {
          raw_info: case email_location
                    when :raw_info_object
                      { mail: email_value }
                    when :raw_info_hash
                      { 'mail' => email_value }
                    else
                      {}
                    end
        }
      )
    end

    def verify_user_attributes(user, expected_email: ldap_email)
      expect(user.email).to eq(expected_email)
      expect(user.provider).to eq('ldap')
      expect(user.uid).to eq(ldap_uid)
    end

    context 'when email is in auth.info.email' do
      let(:auth_hash) { build_auth_hash(email_location: :info) }

      it 'creates a new user with the email from auth.info' do
        expect { User.from_omniauth(auth_hash) }.to change(User, :count).by(1)

        user = User.last
        verify_user_attributes(user)
        expect(user.name).to eq(ldap_name)
      end
    end

    context 'when email is missing from auth.info but present in raw_info.mail' do
      let(:auth_hash) { build_auth_hash(email_location: :raw_info_object) }

      it 'creates a new user with the email from raw_info.mail' do
        expect { User.from_omniauth(auth_hash) }.to change(User, :count).by(1)

        verify_user_attributes(User.last)
      end
    end

    context 'when email is in raw_info as a hash key' do
      let(:auth_hash) { build_auth_hash(email_location: :raw_info_hash) }

      it 'creates a new user with the email from raw_info["mail"]' do
        expect { User.from_omniauth(auth_hash) }.to change(User, :count).by(1)

        verify_user_attributes(User.last)
      end
    end

    context 'when email is returned as an array' do
      let(:auth_hash) do
        build_auth_hash(email_location: :raw_info_hash, email_value: [ldap_email, 'alternate@email.com'])
      end

      it 'uses the first email from the array' do
        expect { User.from_omniauth(auth_hash) }.to change(User, :count).by(1)

        verify_user_attributes(User.last)
      end
    end

    context 'when updating an existing LDAP user' do
      let!(:existing_user) { create(:user, email: ldap_email, provider: nil, uid: nil) }
      let(:auth_hash) { build_auth_hash(email_location: :info) }

      it 'updates the provider and uid' do
        expect { User.from_omniauth(auth_hash) }.not_to change(User, :count)

        existing_user.reload
        verify_user_attributes(existing_user)
      end
    end

    context 'when no email can be extracted' do
      let(:auth_hash) do
        OmniAuth::AuthHash.new(
          provider: 'ldap',
          uid: ldap_uid,
          info: {
            email: nil,
            name: ldap_name
          },
          extra: {
            raw_info: {}
          }
        )
      end

      it 'raises an error' do
        expect { User.from_omniauth(auth_hash) }.to raise_error(ArgumentError, /Email is required/)
      end
    end
  end
end
