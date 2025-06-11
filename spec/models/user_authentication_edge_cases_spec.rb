# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  include LoginHelpers

  describe '.from_omniauth - Edge Cases' do
    let(:base_auth) { mock_omniauth_response(build(:user, email: 'test@example.com'), provider: 'oidc') }

    describe 'race condition handling' do
      it 'handles concurrent user creation attempts gracefully' do
        auth = base_auth

        # Simulate race condition by stubbing find_or_initialize_by to return different instances
        user1 = build(:user, email: 'test@example.com')
        user2 = build(:user, email: 'test@example.com')

        allow(User).to receive(:find_or_initialize_by).and_return(user1, user2)
        allow(user1).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique.new('Duplicate email'))
        allow(user2).to receive(:save!).and_return(true)

        # Should retry and succeed on second attempt
        expect(Rails.logger).to receive(:warn).with(/Race condition detected/)

        result = User.from_omniauth(auth)
        expect(result).to eq(user2)
      end

      it 'fails after maximum retry attempts' do
        auth = base_auth

        # Simulate persistent race condition
        allow(User).to receive(:find_or_initialize_by).and_return(build(:user, email: 'test@example.com'))
        allow_any_instance_of(User).to receive(:save!).and_raise(
          ActiveRecord::RecordNotUnique.new('Persistent duplicate')
        )

        expect(Rails.logger).to receive(:warn).with(/Race condition detected/).at_least(:once)
        expect(Rails.logger).to receive(:error).with(/Failed to create user after \d+ attempts/)

        expect { User.from_omniauth(auth) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    describe 'LDAP email array handling' do
      let(:ldap_auth) { mock_omniauth_response(build(:user), provider: 'ldap') }

      it 'handles valid email array correctly' do
        ldap_auth.info.email = nil
        ldap_auth.extra.raw_info.mail = ['test@example.com', 'test2@example.com']

        user = User.from_omniauth(ldap_auth)
        expect(user.email).to eq('test@example.com')
      end

      it 'filters out nil and blank values from email array' do
        ldap_auth.info.email = nil
        ldap_auth.extra.raw_info.mail = [nil, '', '  ', 'valid@example.com']

        user = User.from_omniauth(ldap_auth)
        expect(user.email).to eq('valid@example.com')
      end

      it 'handles empty array gracefully' do
        ldap_auth.info.email = nil
        ldap_auth.extra.raw_info.mail = []

        expect { User.from_omniauth(ldap_auth) }.to raise_error(ArgumentError, /Email is required/)
      end

      it 'handles array with only invalid values' do
        ldap_auth.info.email = nil
        ldap_auth.extra.raw_info.mail = [nil, '', '   ']

        expect { User.from_omniauth(ldap_auth) }.to raise_error(ArgumentError, /Email is required/)
      end
    end

    describe 'provider switching' do
      let(:existing_user) { create(:user, email: 'test@example.com', provider: 'ldap', uid: 'ldap123') }

      it 'logs provider switching from LDAP to OIDC' do
        auth = base_auth
        auth.provider = 'oidc'
        auth.uid = 'oidc456'
        auth.info.email = existing_user.email.upcase # Test case insensitivity too

        expect(Rails.logger).to receive(:warn).with(/switching authentication provider from 'ldap' to 'oidc'/)
        expect(Rails.logger).to receive(:info).with(/Previous UID: ldap123, New UID: oidc456/)

        user = User.from_omniauth(auth)
        expect(user.id).to eq(existing_user.id)
        expect(user.provider).to eq('oidc')
        expect(user.uid).to eq('oidc456')
      end

      it 'logs provider switching from GitHub to OIDC' do
        existing_user.update!(provider: 'github', uid: 'github789')

        auth = base_auth
        auth.provider = 'oidc'
        auth.uid = 'oidc456'
        auth.info.email = existing_user.email

        expect(Rails.logger).to receive(:warn).with(/switching authentication provider from 'github' to 'oidc'/)

        user = User.from_omniauth(auth)
        expect(user.provider).to eq('oidc')
      end

      it 'does not log when provider stays the same' do
        auth = base_auth
        auth.provider = existing_user.provider
        auth.uid = 'new_uid'
        auth.info.email = existing_user.email

        expect(Rails.logger).not_to receive(:warn).with(/switching authentication provider/)

        User.from_omniauth(auth)
      end
    end

    describe 'password security improvements' do
      it 'uses full-length Devise token for new users' do
        auth = base_auth

        expect(Devise).to receive(:friendly_token).with(no_args).and_return('full_length_secure_token')

        user = User.from_omniauth(auth)
        expect(user.password).to eq('full_length_secure_token')
      end

      it 'does not change password for existing users' do
        existing_user = create(:user, email: 'test@example.com', password: 'original_password')

        auth = base_auth
        auth.info.email = existing_user.email

        user = User.from_omniauth(auth)
        # Password should remain unchanged (we can't test the exact value due to encryption)
        expect(user.id).to eq(existing_user.id)
        expect(user.encrypted_password).to eq(existing_user.encrypted_password)
      end
    end

    describe 'email extraction edge cases' do
      it 'prioritizes auth.info.email over other sources' do
        auth = base_auth
        auth.info.email = 'primary@example.com'
        auth.extra.raw_info.acct = 'secondary@example.com'

        user = User.from_omniauth(auth)
        expect(user.email).to eq('primary@example.com')
      end

      it 'falls back to acct when email is blank' do
        auth = base_auth
        auth.info.email = ''
        auth.extra.raw_info.acct = 'fallback@example.com'

        user = User.from_omniauth(auth)
        expect(user.email).to eq('fallback@example.com')
      end

      it 'uses LDAP mail when other sources are unavailable' do
        auth = mock_omniauth_response(build(:user), provider: 'ldap')
        auth.info.email = nil
        auth.extra.raw_info.acct = nil
        auth.extra.raw_info.mail = 'ldap@example.com'

        user = User.from_omniauth(auth)
        expect(user.email).to eq('ldap@example.com')
      end

      it 'raises error when no email source is available' do
        auth = base_auth
        auth.info.email = nil
        auth.extra.raw_info.acct = nil

        expect { User.from_omniauth(auth) }.to raise_error(ArgumentError, /Email is required/)
      end
    end

    describe 'database constraint enforcement' do
      it 'prevents duplicate provider/uid combinations' do
        # Create first user
        auth1 = base_auth
        auth1.provider = 'oidc'
        auth1.uid = 'unique123'
        auth1.info.email = 'user1@example.com'
        User.from_omniauth(auth1)

        # Try to create second user with same provider/uid but different email
        auth2 = base_auth
        auth2.provider = 'oidc'
        auth2.uid = 'unique123' # Same UID
        auth2.info.email = 'user2@example.com' # Different email

        expect { User.from_omniauth(auth2) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it 'allows same uid for different providers' do
        # Create OIDC user
        auth1 = base_auth
        auth1.provider = 'oidc'
        auth1.uid = 'same123'
        auth1.info.email = 'user1@example.com'
        user1 = User.from_omniauth(auth1)

        # Create LDAP user with same UID (different provider)
        auth2 = base_auth
        auth2.provider = 'ldap'
        auth2.uid = 'same123' # Same UID, different provider
        auth2.info.email = 'user2@example.com'

        expect { User.from_omniauth(auth2) }.not_to raise_error
        user2 = User.from_omniauth(auth2)
        expect(user2.id).not_to eq(user1.id)
      end

      it 'allows nil provider and uid for local users' do
        # This should not conflict with the constraint since local users have nil provider/uid
        local_user1 = create(:user, email: 'local1@example.com', provider: nil, uid: nil)
        local_user2 = create(:user, email: 'local2@example.com', provider: nil, uid: nil)

        expect(local_user1).to be_persisted
        expect(local_user2).to be_persisted
      end
    end

    describe 'transaction rollback behavior' do
      it 'does not create partial user records on failure' do
        auth = base_auth

        # Mock failure during save
        allow_any_instance_of(User).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(User.new))

        initial_count = User.count

        expect { User.from_omniauth(auth) }.to raise_error(ActiveRecord::RecordInvalid)

        # Should not have created any user records
        expect(User.count).to eq(initial_count)
      end
    end

    describe 'name handling' do
      it 'preserves existing user names' do
        existing_user = create(:user, email: 'test@example.com', name: 'Original Name')

        auth = base_auth
        auth.info.email = existing_user.email
        auth.info.name = 'New Name From Provider'

        user = User.from_omniauth(auth)
        expect(user.name).to eq('Original Name')  # Should preserve original
      end

      it 'sets name for new users from auth' do
        auth = base_auth
        auth.info.name = 'Provider Name'

        user = User.from_omniauth(auth)
        expect(user.name).to eq('Provider Name')
      end

      it 'sets fallback name when auth name is blank' do
        auth = base_auth
        auth.info.name = ''
        auth.provider = 'oidc'

        user = User.from_omniauth(auth)
        expect(user.name).to eq('oidc user')
      end

      it 'updates blank names on existing users' do
        existing_user = create(:user, email: 'test@example.com', name: '')

        auth = base_auth
        auth.info.email = existing_user.email
        auth.info.name = 'Updated Name'

        user = User.from_omniauth(auth)
        expect(user.name).to eq('Updated Name')
      end
    end
  end
end
