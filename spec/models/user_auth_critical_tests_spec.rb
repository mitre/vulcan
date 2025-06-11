# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  include LoginHelpers

  describe '.from_omniauth - Critical Edge Cases' do
    describe 'case sensitivity fix verification' do
      it 'finds existing user regardless of email case' do
        # Create user with lowercase email
        create(:user, email: 'user@example.com')

        # Login with uppercase email
        auth = mock_omniauth_response(build(:user, email: 'USER@EXAMPLE.COM'), provider: 'oidc')

        expect { User.from_omniauth(auth) }.not_to change(User, :count)

        user = User.from_omniauth(auth)
        expect(user.email).to eq('user@example.com') # Original case preserved
      end

      it 'handles mixed case variations consistently' do
        create(:user, email: 'test@domain.com')

        test_cases = ['Test@Domain.com', 'TEST@DOMAIN.COM', 'test@DOMAIN.com']

        test_cases.each do |test_email|
          auth = mock_omniauth_response(build(:user, email: test_email), provider: 'oidc')

          expect { User.from_omniauth(auth) }.not_to change(User, :count)

          user = User.from_omniauth(auth)
          expect(user.email).to eq('test@domain.com')
        end
      end
    end

    describe 'LDAP email array handling' do
      it 'handles valid email array correctly' do
        auth = mock_omniauth_response(build(:user), provider: 'ldap')
        auth.info.email = nil
        auth.extra.raw_info.mail = ['test@example.com', 'test2@example.com']

        user = User.from_omniauth(auth)
        expect(user.email).to eq('test@example.com')
      end

      it 'filters out invalid values from email array' do
        auth = mock_omniauth_response(build(:user), provider: 'ldap')
        auth.info.email = nil
        auth.extra.raw_info.mail = [nil, '', '  ', 'valid@example.com']

        user = User.from_omniauth(auth)
        expect(user.email).to eq('valid@example.com')
      end

      it 'raises error when no valid email found in array' do
        auth = mock_omniauth_response(build(:user), provider: 'ldap')
        auth.info.email = nil
        auth.extra.raw_info.mail = [nil, '', '   ']

        expect { User.from_omniauth(auth) }.to raise_error(ArgumentError, /Email is required/)
      end
    end

    describe 'provider switching logging' do
      it 'logs when user switches from LDAP to OIDC' do
        user = create(:user, email: 'test@example.com', provider: 'ldap', uid: 'ldap123')

        auth = mock_omniauth_response(build(:user, email: user.email), provider: 'oidc')
        auth.uid = 'oidc456'

        expect(Rails.logger).to receive(:warn).with(/switching authentication provider from 'ldap' to 'oidc'/)
        expect(Rails.logger).to receive(:info).with(/Previous UID: ldap123, New UID: oidc456/)
        allow(Rails.logger).to receive(:info) # Allow other info logs

        result_user = User.from_omniauth(auth)
        expect(result_user.id).to eq(user.id)
        expect(result_user.provider).to eq('oidc')
        expect(result_user.uid).to eq('oidc456')
      end

      it 'does not log when provider stays the same' do
        user = create(:user, email: 'test@example.com', provider: 'oidc', uid: 'old_uid')

        auth = mock_omniauth_response(build(:user, email: user.email), provider: 'oidc')
        auth.uid = 'new_uid'

        expect(Rails.logger).not_to receive(:warn).with(/switching authentication provider/)

        User.from_omniauth(auth)
      end
    end

    describe 'database constraint enforcement' do
      it 'prevents duplicate provider/uid combinations' do
        # Create first user
        auth1 = mock_omniauth_response(build(:user, email: 'user1@example.com'), provider: 'oidc')
        auth1.uid = 'unique123'
        User.from_omniauth(auth1)

        # Try to create second user with same provider/uid but different email
        auth2 = mock_omniauth_response(build(:user, email: 'user2@example.com'), provider: 'oidc')
        auth2.uid = 'unique123' # Same UID

        expect { User.from_omniauth(auth2) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it 'allows same uid for different providers' do
        # Create OIDC user
        auth1 = mock_omniauth_response(build(:user, email: 'user1@example.com'), provider: 'oidc')
        auth1.uid = 'same123'
        user1 = User.from_omniauth(auth1)

        # Create LDAP user with same UID (different provider)
        auth2 = mock_omniauth_response(build(:user, email: 'user2@example.com'), provider: 'ldap')
        auth2.uid = 'same123' # Same UID, different provider

        expect { User.from_omniauth(auth2) }.not_to raise_error
        user2 = User.from_omniauth(auth2)
        expect(user2.id).not_to eq(user1.id)
      end
    end

    describe 'password security' do
      it 'uses full-length Devise token for new users' do
        auth = mock_omniauth_response(build(:user, email: 'new@example.com'), provider: 'oidc')

        # Mock to verify full token is used
        expect(Devise).to receive(:friendly_token).with(no_args).and_call_original

        user = User.from_omniauth(auth)
        expect(user.password).to be_present
        expect(user.password.length).to be >= 20  # Devise.friendly_token is typically much longer
      end

      it 'does not change password for existing users' do
        existing_user = create(:user, email: 'test@example.com', password: 'original_password')
        original_encrypted = existing_user.encrypted_password

        auth = mock_omniauth_response(build(:user, email: existing_user.email), provider: 'oidc')

        user = User.from_omniauth(auth)
        expect(user.id).to eq(existing_user.id)
        expect(user.encrypted_password).to eq(original_encrypted)
      end
    end

    describe 'name preservation' do
      it 'preserves existing user names' do
        existing_user = create(:user, email: 'test@example.com', name: 'Original Name')

        auth = mock_omniauth_response(build(:user, email: existing_user.email), provider: 'oidc')
        auth.info.name = 'New Name From Provider'

        user = User.from_omniauth(auth)
        expect(user.name).to eq('Original Name')
      end

      it 'sets name for new users from auth' do
        auth = mock_omniauth_response(build(:user, email: 'new@example.com'), provider: 'oidc')
        auth.info.name = 'Provider Name'

        user = User.from_omniauth(auth)
        expect(user.name).to eq('Provider Name')
      end

      it 'sets fallback name when auth name is blank' do
        auth = mock_omniauth_response(build(:user, email: 'new@example.com'), provider: 'oidc')
        auth.info.name = ''

        user = User.from_omniauth(auth)
        expect(user.name).to eq('oidc user')
      end
    end

    describe 'email validation' do
      it 'raises error when no email source is available' do
        auth = mock_omniauth_response(build(:user), provider: 'oidc')
        auth.info.email = nil
        auth.extra.raw_info = {}

        expect { User.from_omniauth(auth) }.to raise_error(ArgumentError, /Email is required/)
      end

      it 'prioritizes auth.info.email over other sources' do
        auth = mock_omniauth_response(build(:user), provider: 'ldap')
        auth.info.email = 'primary@example.com'
        auth.extra.raw_info.acct = 'secondary@example.com'
        auth.extra.raw_info.mail = 'tertiary@example.com'

        user = User.from_omniauth(auth)
        expect(user.email).to eq('primary@example.com')
      end
    end
  end
end
