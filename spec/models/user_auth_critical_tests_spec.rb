# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  include LoginHelpers

  describe '.from_omniauth - Critical Edge Cases' do
    describe 'case sensitivity fix verification' do
      it 'finds existing user regardless of email case' do
        # Create user with oidc provider to match auth
        create(:user, email: 'user@example.com', provider: 'oidc', uid: 'oidc-1')

        # Login with uppercase email — same provider
        auth = mock_omniauth_response(build(:user, email: 'USER@EXAMPLE.COM'), provider: 'oidc')

        expect { User.from_omniauth(auth) }.not_to change(User, :count)

        user = User.from_omniauth(auth)
        expect(user.email).to eq('user@example.com') # Original case preserved
      end

      it 'handles mixed case variations consistently' do
        create(:user, email: 'test@domain.com', provider: 'oidc', uid: 'oidc-2')

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

    describe 'provider conflict protection' do
      it 'blocks login when existing local user tries to auth via OIDC' do
        create(:user, email: 'admin@example.com', provider: nil, uid: nil)

        auth = mock_omniauth_response(build(:user, email: 'admin@example.com'), provider: 'oidc')
        auth.uid = 'oidc-123'

        expect { User.from_omniauth(auth) }.to raise_error(User::ProviderConflictError, /already exists.*local/)
      end

      it 'blocks login when LDAP user tries to auth via OIDC' do
        create(:user, email: 'test@example.com', provider: 'ldap', uid: 'ldap-123')

        auth = mock_omniauth_response(build(:user, email: 'test@example.com'), provider: 'oidc')
        auth.uid = 'oidc-456'

        expect { User.from_omniauth(auth) }.to raise_error(User::ProviderConflictError, /already exists.*ldap/)
      end

      it 'does not modify provider/uid on existing user' do
        user = create(:user, email: 'admin@example.com', provider: 'ldap', uid: 'ldap-orig')

        auth = mock_omniauth_response(build(:user, email: 'admin@example.com'), provider: 'oidc')
        auth.uid = 'oidc-new'

        expect { User.from_omniauth(auth) }.to raise_error(User::ProviderConflictError)

        user.reload
        expect(user.provider).to eq('ldap')
        expect(user.uid).to eq('ldap-orig')
      end

      it 'allows login when provider matches (same provider re-auth)' do
        user = create(:user, email: 'test@example.com', provider: 'oidc', uid: 'old-uid')

        auth = mock_omniauth_response(build(:user, email: user.email), provider: 'oidc')
        auth.uid = 'new-uid'

        result = User.from_omniauth(auth)
        expect(result.id).to eq(user.id)
        expect(result.uid).to eq('new-uid')
      end

      it 'allows new user creation via any provider' do
        auth = mock_omniauth_response(build(:user, email: 'brand-new@example.com'), provider: 'oidc')
        auth.uid = 'oidc-new'

        expect { User.from_omniauth(auth) }.to change(User, :count).by(1)
        user = User.find_by(email: 'brand-new@example.com')
        expect(user.provider).to eq('oidc')
        expect(user.uid).to eq('oidc-new')
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
        expect(user.password.length).to be >= 20 # Devise.friendly_token is typically much longer
      end

      it 'does not change password for existing users' do
        existing_user = create(:user, email: 'test@example.com', password: 'original_password',
                                      provider: 'oidc', uid: 'oidc-pw')
        original_encrypted = existing_user.encrypted_password

        auth = mock_omniauth_response(build(:user, email: existing_user.email), provider: 'oidc')

        user = User.from_omniauth(auth)
        expect(user.id).to eq(existing_user.id)
        expect(user.encrypted_password).to eq(original_encrypted)
      end
    end

    describe 'name preservation' do
      it 'preserves existing user names' do
        existing_user = create(:user, email: 'test@example.com', name: 'Original Name',
                                      provider: 'oidc', uid: 'oidc-name')

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
        # Create an OpenStruct raw_info that responds to multiple fields
        auth.extra.raw_info = OpenStruct.new(
          acct: 'secondary@example.com',
          mail: 'tertiary@example.com'
        )

        user = User.from_omniauth(auth)
        expect(user.email).to eq('primary@example.com')
      end
    end
  end
end
