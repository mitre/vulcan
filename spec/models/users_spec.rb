# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  include LoginHelpers

  describe '.from_omniauth' do
    context 'when registering using an omniauth provider' do
      let(:user1) { build(:user) }

      it 'creates the user and sets the user attributes' do
        auth = mock_omniauth_response(user1)
        expect { described_class.from_omniauth(auth) }.to change(described_class, :count).by 1

        created_user = described_class.find_by(email: user1.email)

        expect(created_user.email).to eq auth.info.email
        expect(created_user.name).to eq auth.info.name
        expect(created_user.provider).to eq auth.provider
        expect(created_user.provider).to eq auth.provider
      end
    end

    context 'when accessing an existing account using an omniauth provider' do
      let(:user1) { create(:user) }

      it 'does not create a duplicate user' do
        auth = mock_omniauth_response(user1)
        expect { described_class.from_omniauth(auth) }.not_to change(described_class, :count)
      end
    end

    context 'when email casing differs between logins' do
      let(:user1) { create(:user, email: 'user@example.com') }

      it 'finds existing user regardless of email case' do
        # First login with different case
        auth = mock_omniauth_response(user1)
        auth.info.email = 'User@Example.com' # Different case

        # Should not create a duplicate user
        expect { described_class.from_omniauth(auth) }.not_to change(described_class, :count)

        # Should find and update the existing user
        updated_user = described_class.from_omniauth(auth)
        expect(updated_user.id).to eq(user1.id)
        expect(updated_user.email).to eq('user@example.com') # Original case preserved
      end

      it 'handles multiple case variations consistently' do
        # Create user with lowercase email
        user = create(:user, email: 'test@domain.com')

        # Test various case combinations that should all find the same user
        test_cases = [
          'Test@Domain.com',
          'TEST@DOMAIN.COM',
          'test@DOMAIN.com',
          'Test@domain.COM'
        ]

        test_cases.each do |test_email|
          auth = mock_omniauth_response(user)
          auth.info.email = test_email

          result_user = described_class.from_omniauth(auth)
          expect(result_user.id).to eq(user.id),
                                    "Failed to find existing user for email case: #{test_email}"
        end

        # Verify only one user exists
        expect(described_class.where(email: 'test@domain.com').count).to eq(1)
      end
    end
  end
end
