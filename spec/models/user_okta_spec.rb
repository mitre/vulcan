# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  include LoginHelpers

  describe '.from_omniauth with OIDC/OKTA' do
    context 'when an existing user logs in with OKTA for the first time' do
      let(:existing_user) { create(:user, email: 'test@example.com', provider: nil, uid: nil) }
      
      it 'updates the existing user with OKTA provider and uid' do
        auth = OmniAuth::AuthHash.new({
          provider: 'oidc',
          uid: 'okta-uid-12345',
          info: {
            email: existing_user.email,
            name: existing_user.name
          },
          credentials: {
            id_token: 'fake-id-token'
          }
        })

        expect { described_class.from_omniauth(auth) }.not_to change(described_class, :count)
        
        existing_user.reload
        expect(existing_user.provider).to eq('oidc')
        expect(existing_user.uid).to eq('okta-uid-12345')
      end
    end

    context 'when an existing OKTA user logs in again' do
      let(:okta_user) { create(:user, email: 'okta@example.com', provider: 'oidc', uid: 'okta-uid-12345') }
      
      it 'finds the user by provider and uid without creating duplicates' do
        auth = OmniAuth::AuthHash.new({
          provider: 'oidc',
          uid: 'okta-uid-12345',
          info: {
            email: okta_user.email,
            name: okta_user.name
          },
          credentials: {
            id_token: 'fake-id-token'
          }
        })

        expect { described_class.from_omniauth(auth) }.not_to change(described_class, :count)
        
        user = described_class.from_omniauth(auth)
        expect(user.id).to eq(okta_user.id)
      end
    end

    context 'when a new user logs in with OKTA' do
      it 'creates a new user with OKTA provider and uid' do
        auth = OmniAuth::AuthHash.new({
          provider: 'oidc',
          uid: 'new-okta-uid-67890',
          info: {
            email: 'newuser@example.com',
            name: 'New User'
          },
          credentials: {
            id_token: 'fake-id-token'
          }
        })

        expect { described_class.from_omniauth(auth) }.to change(described_class, :count).by(1)
        
        new_user = described_class.find_by(email: 'newuser@example.com')
        expect(new_user.provider).to eq('oidc')
        expect(new_user.uid).to eq('new-okta-uid-67890')
        expect(new_user.name).to eq('New User')
      end
    end
  end
end