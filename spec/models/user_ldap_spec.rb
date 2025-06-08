# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe '.from_omniauth with LDAP' do
    let(:ldap_uid) { 'zoidberg' }
    let(:ldap_email) { 'zoidberg@planetexpress.com' }
    let(:ldap_name) { 'John A. Zoidberg' }
    
    context 'when email is in auth.info.email' do
      let(:auth_hash) do
        OmniAuth::AuthHash.new(
          provider: 'ldap',
          uid: ldap_uid,
          info: {
            email: ldap_email,
            name: ldap_name
          },
          extra: {
            raw_info: {}
          }
        )
      end

      it 'creates a new user with the email from auth.info' do
        expect { User.from_omniauth(auth_hash) }.to change(User, :count).by(1)
        
        user = User.last
        expect(user.email).to eq(ldap_email)
        expect(user.provider).to eq('ldap')
        expect(user.uid).to eq(ldap_uid)
        expect(user.name).to eq(ldap_name)
      end
    end

    context 'when email is missing from auth.info but present in raw_info.mail' do
      let(:auth_hash) do
        OmniAuth::AuthHash.new(
          provider: 'ldap',
          uid: ldap_uid,
          info: {
            email: nil,
            name: ldap_name
          },
          extra: {
            raw_info: OpenStruct.new(mail: ldap_email)
          }
        )
      end

      it 'creates a new user with the email from raw_info.mail' do
        expect { User.from_omniauth(auth_hash) }.to change(User, :count).by(1)
        
        user = User.last
        expect(user.email).to eq(ldap_email)
        expect(user.provider).to eq('ldap')
        expect(user.uid).to eq(ldap_uid)
      end
    end

    context 'when email is in raw_info as a hash key' do
      let(:auth_hash) do
        OmniAuth::AuthHash.new(
          provider: 'ldap',
          uid: ldap_uid,
          info: {
            email: nil,
            name: ldap_name
          },
          extra: {
            raw_info: { 'mail' => ldap_email }
          }
        )
      end

      it 'creates a new user with the email from raw_info["mail"]' do
        expect { User.from_omniauth(auth_hash) }.to change(User, :count).by(1)
        
        user = User.last
        expect(user.email).to eq(ldap_email)
        expect(user.provider).to eq('ldap')
        expect(user.uid).to eq(ldap_uid)
      end
    end

    context 'when email is returned as an array' do
      let(:auth_hash) do
        OmniAuth::AuthHash.new(
          provider: 'ldap',
          uid: ldap_uid,
          info: {
            email: nil,
            name: ldap_name
          },
          extra: {
            raw_info: { 'mail' => [ldap_email, 'alternate@email.com'] }
          }
        )
      end

      it 'uses the first email from the array' do
        expect { User.from_omniauth(auth_hash) }.to change(User, :count).by(1)
        
        user = User.last
        expect(user.email).to eq(ldap_email)
      end
    end

    context 'when updating an existing LDAP user' do
      let!(:existing_user) { create(:user, email: ldap_email, provider: nil, uid: nil) }
      let(:auth_hash) do
        OmniAuth::AuthHash.new(
          provider: 'ldap',
          uid: ldap_uid,
          info: {
            email: ldap_email,
            name: ldap_name
          },
          extra: {
            raw_info: {}
          }
        )
      end

      it 'updates the provider and uid' do
        expect { User.from_omniauth(auth_hash) }.not_to change(User, :count)
        
        existing_user.reload
        expect(existing_user.provider).to eq('ldap')
        expect(existing_user.uid).to eq(ldap_uid)
      end
    end
  end
end