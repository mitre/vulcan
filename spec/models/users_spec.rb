# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
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

    # First-user-admin via callback with advisory lock for race condition protection
    context 'when VULCAN_FIRST_USER_ADMIN is true (default)' do
      let(:new_user) { build(:user) }

      before do
        # Stub first_user_admin setting to true
        stub_admin_bootstrap_setting(first_user_admin: true)
      end

      context 'and no admin users exist' do # rubocop:disable RSpec/NestedGroups
        before do
          # Ensure no admin users exist
          described_class.where(admin: true).destroy_all
        end

        it 'promotes the first new user to admin' do
          auth = mock_omniauth_response(new_user)
          created_user = described_class.from_omniauth(auth)

          expect(created_user.admin).to be true
        end

        it 'does not promote subsequent new users to admin' do
          # First user becomes admin
          first_user_data = build(:user)
          auth1 = mock_omniauth_response(first_user_data)
          first_user = described_class.from_omniauth(auth1)
          expect(first_user.admin).to be true

          # Second user should NOT become admin
          second_user_data = build(:user)
          auth2 = mock_omniauth_response(second_user_data)
          second_user = described_class.from_omniauth(auth2)
          expect(second_user.admin).to be false
        end

        it 'does not promote an existing user logging in again' do
          # Create an admin FIRST so subsequent users don't get promoted
          create(:user, admin: true)
          # Create a non-admin user (won't be promoted because admin exists)
          existing_user = create(:user, admin: false)

          # Existing user logs in via omniauth - should NOT be promoted
          auth = mock_omniauth_response(existing_user)
          returned_user = described_class.from_omniauth(auth)

          expect(returned_user.admin).to be false
        end
      end

      context 'and admin users already exist' do # rubocop:disable RSpec/NestedGroups
        let!(:existing_admin) { create(:user, admin: true) } # -- side effect: prevents first-user-admin promotion

        it 'does not promote new users to admin' do
          auth = mock_omniauth_response(new_user)
          created_user = described_class.from_omniauth(auth)

          expect(created_user.admin).to be false
        end
      end
    end

    context 'when VULCAN_FIRST_USER_ADMIN is false' do
      let(:new_user) { build(:user) }

      before do
        # Stub first_user_admin setting to false
        stub_admin_bootstrap_setting(first_user_admin: false)
        # Ensure no admin users exist
        described_class.where(admin: true).destroy_all
      end

      it 'does not promote first user to admin even when no admins exist' do
        auth = mock_omniauth_response(new_user)
        created_user = described_class.from_omniauth(auth)

        expect(created_user.admin).to be false
      end
    end
  end
end
