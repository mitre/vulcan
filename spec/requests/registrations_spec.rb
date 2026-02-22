# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Registrations' do
  include LoginHelpers
  include ActiveJob::TestHelper

  before do
    Rails.application.reload_routes!
  end

  let(:user1) { build(:user, email: "registration-test-#{SecureRandom.hex(4)}@example.com") }

  context 'when local login is disabled' do
    before do
      stub_local_login_setting(enabled: false)
    end

    it 'does not allow users to register' do
      expect do
        post '/users', params: {
          user: {
            name: user1.name,
            email: user1.email,
            password: user1.password,
            password_confirmation: user1.password
          }
        }
      end.not_to change(User, :count)

      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include('registration is not currently enabled')
    end
  end

  context 'local login is enabled' do
    before do
      stub_local_login_setting(enabled: true)
    end

    it 'allows users to register' do
      expect do
        post '/users', params: {
          user: {
            name: user1.name,
            email: user1.email,
            password: user1.password,
            password_confirmation: user1.password
          }
        }
      end.to change(User, :count).by(1)

      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include(I18n.t('devise.registrations.signed_up'))
    end
  end

  context 'email confirmation enabled', :truncation do
    before do
      stub_local_login_setting(enabled: true, email_confirmation: true)
      allow(Settings).to receive_messages(
        local_login: double('local_login', enabled: true, email_confirmation: true),
        contact_email: 'admin@example.com'
      )

      # Ensure email delivery is enabled for this test
      ActionMailer::Base.perform_deliveries = true
      ActionMailer::Base.delivery_method = :test
      ActionMailer::Base.deliveries.clear
    end

    it 'allows users to register' do
      expect do
        post '/users', params: {
          user: {
            name: user1.name,
            email: user1.email,
            password: user1.password,
            password_confirmation: user1.password
          }
        }
      end.to change(User, :count).by(1)

      created_user = User.find_by(email: user1.email)
      expect(created_user).to be_present
      expect(created_user.confirmed?).to be false

      expect(response).to have_http_status(:redirect)
      # Check that confirmation email was sent (indicates successful registration)
      expect(ActionMailer::Base.deliveries.count).to eq(1)
      expect(ActionMailer::Base.deliveries.last.subject).to include('Confirmation')
    end
  end

  context 'email confirmation disabled' do
    before do
      stub_local_login_setting(email_confirmation: false)
    end

    it 'allows users to register without confirming email' do
      expect do
        post '/users', params: {
          user: {
            name: user1.name,
            email: user1.email,
            password: user1.password,
            password_confirmation: user1.password
          }
        }
      end.to change(User, :count).by(1)

      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include(I18n.t('devise.registrations.signed_up'))
    end
  end

  context 'empty email', :truncation do
    before do
      stub_base_settings(contact_email: 'contact_email@test.com')
      stub_local_login_setting(email_confirmation: true)
      allow(Settings.local_login).to receive(:email_confirmation).and_return(true)
    end

    it 'checks if contact email is empty' do
      expect do
        post '/users', params: {
          user: {
            name: user1.name,
            email: user1.email,
            password: user1.password,
            password_confirmation: user1.password
          }
        }
      end.to change(User, :count).by(1)

      created_user = User.find_by(email: user1.email)
      expect(created_user).to be_present
      expect(created_user.confirmed?).to be false
    end
  end

  context 'update user info', :truncation do
    let(:existing_user) { create(:user) }
    let(:new_user_data) { build(:user, email: "update-test-#{SecureRandom.hex(4)}@example.com") }

    before do
      stub_local_login_setting(enabled: true, email_confirmation: true)
      allow(Settings).to receive_messages(
        local_login: double('local_login', enabled: true, email_confirmation: true),
        contact_email: 'admin@example.com'
      )

      # Ensure email delivery is enabled for this test
      ActionMailer::Base.perform_deliveries = true
      ActionMailer::Base.delivery_method = :test
      ActionMailer::Base.deliveries.clear

      sign_in existing_user
    end

    it 'checks if user is updated' do
      put '/users', params: {
        user: {
          name: new_user_data.name,
          email: new_user_data.email,
          password: new_user_data.password,
          password_confirmation: new_user_data.password,
          current_password: existing_user.password
        }
      }

      expect(response).to have_http_status(:redirect)
      # Devise sends: confirmation email + email-changed notification + password-changed notification
      expect(ActionMailer::Base.deliveries.count).to eq(3)
      confirmation_email = ActionMailer::Base.deliveries.find { |e| e.subject.include?('Confirmation') }
      expect(confirmation_email).to be_present
      expect(confirmation_email.to).to include(new_user_data.email)

      existing_user.reload.confirm

      expect(existing_user.name).to eq(new_user_data.name)
      expect(existing_user.email).to eq(new_user_data.email)
      expect(existing_user.valid_password?(new_user_data.password)).to be true
    end
  end

  context 'update user info without password' do
    let(:existing_user) { create(:user) }
    let(:new_user_data) { build(:user) }

    before do
      sign_in existing_user
    end

    it 'makes sure can not update without password' do
      put '/users', params: {
        user: {
          name: new_user_data.name,
          email: existing_user.email,
          password: existing_user.password,
          password_confirmation: existing_user.password,
          current_password: ''
        }
      }

      # When current_password is wrong, Devise should not update the user
      expect(response).to have_http_status(:unprocessable_entity).or have_http_status(:ok)
      existing_user.reload
      expect(existing_user.name).not_to eq(new_user_data.name)
      # The key test is that the name didn't change due to wrong password
    end
  end

  context 'update ldap user info' do
    let(:ldap_user) { create(:ldap_user) }

    before do
      sign_in ldap_user
    end

    it 'user updates without password' do
      put '/users', params: {
        user: {
          name: user1.name
        }
      }

      expect(response).to have_http_status(:redirect)
      expect(ldap_user.reload.name).to eq(user1.name)
    end
  end

  # First-user-admin via callback with advisory lock for race condition protection
  describe 'first user admin promotion' do
    context 'when VULCAN_FIRST_USER_ADMIN is true and no admins exist' do
      before do
        stub_local_login_setting(enabled: true)
        stub_admin_bootstrap_setting(first_user_admin: true)
        # Ensure no admin users exist
        User.where(admin: true).destroy_all
      end

      it 'promotes the first registered user to admin' do
        post '/users', params: {
          user: {
            name: user1.name,
            email: user1.email,
            password: user1.password,
            password_confirmation: user1.password
          }
        }

        created_user = User.find_by(email: user1.email)
        expect(created_user).to be_present
        expect(created_user.admin).to be true
      end

      it 'does not promote subsequent users to admin' do
        # First user via registration - should become admin
        first_user_email = "first-#{SecureRandom.hex(4)}@example.com"
        first_user_data = build(:user, email: first_user_email)
        expect do
          post '/users', params: {
            user: {
              name: first_user_data.name,
              email: first_user_email,
              password: first_user_data.password,
              password_confirmation: first_user_data.password
            }
          }
        end.to change(User, :count).by(1)
        first_user = User.find_by(email: first_user_email)
        expect(first_user).to be_present
        expect(first_user.admin).to be true

        # Second user created directly (simulates another registration)
        # The callback behavior is the same regardless of how user is created
        second_user = create(:user, admin: false)
        # Reload to get latest state - callback should NOT have promoted them
        second_user.reload
        expect(second_user.admin).to be false
      end
    end

    context 'when VULCAN_FIRST_USER_ADMIN is true but admins already exist' do
      let!(:existing_admin) { create(:user, admin: true) } # -- side effect: prevents first-user-admin promotion

      before do
        stub_local_login_setting(enabled: true)
        stub_admin_bootstrap_setting(first_user_admin: true)
      end

      it 'does not promote new users to admin' do
        post '/users', params: {
          user: {
            name: user1.name,
            email: user1.email,
            password: user1.password,
            password_confirmation: user1.password
          }
        }

        created_user = User.find_by(email: user1.email)
        expect(created_user).to be_present
        expect(created_user.admin).to be false
      end
    end

    context 'when VULCAN_FIRST_USER_ADMIN is false' do
      before do
        stub_local_login_setting(enabled: true)
        stub_admin_bootstrap_setting(first_user_admin: false)
        # Ensure no admin users exist
        User.where(admin: true).destroy_all
      end

      it 'does not promote first user to admin even when no admins exist' do
        post '/users', params: {
          user: {
            name: user1.name,
            email: user1.email,
            password: user1.password,
            password_confirmation: user1.password
          }
        }

        created_user = User.find_by(email: user1.email)
        expect(created_user).to be_present
        expect(created_user.admin).to be false
      end
    end
  end
end
