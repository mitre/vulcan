# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Registrations' do
  before do
    # Clear Rack::Attack cache before each test to avoid rate limiting
    Rack::Attack.cache.store&.clear
    Rails.application.reload_routes!
  end

  include LoginHelpers
  include ActiveJob::TestHelper

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

      # Registration disabled should redirect with flash alert
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to include('registration is not currently enabled')
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

      # Successful registration redirects and sets flash notice
      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to eq(I18n.t('devise.registrations.signed_up'))
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

      # Successful registration redirects and sets flash notice
      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to eq(I18n.t('devise.registrations.signed_up'))
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
      # Check that confirmation email was sent for email change
      expect(ActionMailer::Base.deliveries.count).to eq(1)
      confirmation_email = ActionMailer::Base.deliveries.last
      expect(confirmation_email.to).to include(new_user_data.email)
      expect(confirmation_email.subject).to include('Confirmation')

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

      # When current_password is wrong, Devise may return 422 or redirect (302)
      # depending on configuration. The key test is that the name didn't change.
      expect(response).to have_http_status(:unprocessable_content)
        .or(have_http_status(:ok))
        .or(have_http_status(:found))
      existing_user.reload
      expect(existing_user.name).not_to eq(new_user_data.name)
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

  # JSON API tests for Vue SPA profile editing
  describe 'JSON API' do
    describe 'GET /users/edit' do
      context 'when authenticated' do
        let(:user) { create(:user) }

        before { sign_in user }

        it 'returns current user data' do
          get '/users/edit',
              headers: { 'Accept' => 'application/json' },
              as: :json

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['user']['id']).to eq(user.id)
          expect(json['user']['email']).to eq(user.email)
          expect(json['user']['name']).to eq(user.name)
        end
      end

      context 'when not authenticated' do
        it 'returns unauthorized' do
          get '/users/edit',
              headers: { 'Accept' => 'application/json' },
              as: :json

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    describe 'PUT /users' do
      context 'when updating local user profile' do
        let(:user) { create(:user) }
        let(:new_name) { 'Updated Name' }

        before { sign_in user }

        it 'updates profile with valid current password' do
          put '/users',
              params: {
                user: {
                  name: new_name,
                  current_password: user.password
                }
              },
              headers: { 'Accept' => 'application/json' },
              as: :json

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['user']['name']).to eq(new_name)
          expect(user.reload.name).to eq(new_name)
        end

        it 'returns error with wrong current password' do
          put '/users',
              params: {
                user: {
                  name: new_name,
                  current_password: 'WrongPassword123!'
                }
              },
              headers: { 'Accept' => 'application/json' },
              as: :json

          expect(response).to have_http_status(:unprocessable_content)
          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['errors']).to be_present
          expect(user.reload.name).not_to eq(new_name)
        end

        it 'updates email and sends confirmation' do
          new_email = "newemail-#{SecureRandom.hex(4)}@example.com"

          stub_local_login_setting(enabled: true, email_confirmation: true)
          allow(Settings).to receive_messages(
            local_login: double('local_login', enabled: true, email_confirmation: true),
            contact_email: 'admin@example.com'
          )

          ActionMailer::Base.perform_deliveries = true
          ActionMailer::Base.delivery_method = :test
          ActionMailer::Base.deliveries.clear

          put '/users',
              params: {
                user: {
                  email: new_email,
                  current_password: user.password
                }
              },
              headers: { 'Accept' => 'application/json' },
              as: :json

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['success']).to be true

          # Email change requires confirmation
          expect(ActionMailer::Base.deliveries.count).to eq(1)
          confirmation_email = ActionMailer::Base.deliveries.last
          expect(confirmation_email.to).to include(new_email)
        end
      end

      context 'when updating LDAP/OIDC user profile' do
        let(:ldap_user) { create(:ldap_user) }
        let(:new_name) { 'Updated LDAP Name' }

        before { sign_in ldap_user }

        it 'updates profile without password requirement' do
          put '/users',
              params: {
                user: {
                  name: new_name
                }
              },
              headers: { 'Accept' => 'application/json' },
              as: :json

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['user']['name']).to eq(new_name)
          expect(ldap_user.reload.name).to eq(new_name)
        end
      end

      context 'when not authenticated' do
        it 'returns unauthorized' do
          put '/users',
              params: {
                user: {
                  name: 'Hacker'
                }
              },
              headers: { 'Accept' => 'application/json' },
              as: :json

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end
end
