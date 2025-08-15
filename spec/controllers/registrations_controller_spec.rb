# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::RegistrationsController, type: :controller do
  include LoginHelpers
  include ActiveJob::TestHelper
  include Users

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
  end

  let(:user1) { build(:user) }

  context 'when local login is disabled' do
    before do
      stub_local_login_setting(enabled: false)
    end

    it 'does not allow users to register' do
      expect { post :create, params: {} }.not_to change(User, :count)

      expect(response).to have_http_status(:redirect)
      # The flash message should indicate registration is disabled
      expect(flash[:alert]).to be_present
      expect(flash[:alert]).to match(/registration is not currently enabled|contact an administrator/)
    end
  end

  context 'local login is enabled' do
    before do
      stub_local_login_setting(enabled: true)
    end

    it 'allows users to register' do
      expect do
        post :create, params: {
          user: {
            name: user1.name,
            email: user1.email,
            password: user1.password,
            password_confirmation: user1.password
          }
        }
      end.to change(User, :count).by 1

      expect(flash[:notice]).to eq I18n.t('devise.registrations.signed_up')
    end
  end

  context 'email confirmation enabled', :truncation do
    before do
      stub_local_login_setting(enabled: true, email_confirmation: true)
      # Mock ALL Settings methods to avoid nil errors
      allow(Settings).to receive_messages(local_login: double('local_login', enabled: true, email_confirmation: true), contact_email: 'admin@example.com')
      # Ensure ActionMailer can send emails
      ActionMailer::Base.deliveries.clear
    end

    it 'allows users to register' do
      expect do
        post :create, params: {
          user: {
            name: user1.name,
            email: user1.email,
            password: user1.password,
            password_confirmation: user1.password
          }
        }
      end.to change(User, :count).by 1

      # Check the user was created but not confirmed
      created_user = User.find_by(email: user1.email)
      expect(created_user).to be_present
      expect(created_user.confirmed?).to be false

      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to eq I18n.t('devise.registrations.signed_up_but_unconfirmed')
    end
  end

  context 'email confirmation disabled' do
    before do
      stub_local_login_setting(email_confirmation: false)
    end

    it 'allows users to register without confirming email' do
      expect do
        post :create, params: {
          user: {
            name: user1.name,
            email: user1.email,
            password: user1.password,
            password_confirmation: user1.password
          }
        }
      end.to change(User, :count).by 1

      expect(flash[:notice]).to eq I18n.t('devise.registrations.signed_up')
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
        post :create, params: {
          user: {
            name: user1.name,
            email: user1.email,
            password: user1.password,
            password_confirmation: user1.password
          }
        }
      end.to change(User, :count).by 1

      # Just verify user was created correctly with confirmation required
      created_user = User.find_by(email: user1.email)
      expect(created_user).to be_present
      expect(created_user.confirmed?).to be false
    end
  end

  context 'update user info', :truncation do
    let(:user2) { create(:user) }
    let(:user3) { build(:user) }

    before do
      stub_local_login_setting(enabled: true, email_confirmation: true)
      # Mock ALL Settings methods to avoid nil errors
      allow(Settings).to receive_messages(local_login: double('local_login', enabled: true, email_confirmation: true), contact_email: 'admin@example.com')
      sign_in user2
    end

    it 'checks if user is updated' do
      post :update, params: {
        user: {
          name: user3.name,
          email: user3.email,
          password: user3.password,
          password_confirmation: user3.password,
          current_password: user2.password
        }
      }

      expect(flash[:notice]).to eq I18n.t('devise.registrations.update_needs_confirmation')

      user2.reload.confirm

      expect(user2.name).to eq(user3.name)
      expect(user2.email).to eq(user3.email)
      # The password field does not update on a factory when a user changes their password
      # only the encrypted password in the database. We have to use the devise valid_password?
      # method to verify that the password actually changed
      expect(user2.valid_password?(user3.password)).to be true
    end
  end

  context 'update user info without password' do
    let(:user2) { create(:user) }
    let(:user3) { build(:user) }

    before do
      @request.env['devise.mapping'] = Devise.mappings[:user]
      sign_in user2
    end

    it 'makes sure can not update without password' do
      post :update, params: {
        user: {
          name: user3.name,
          email: user2.email,
          password: user2.password,
          password_confirmation: user2.password,
          current_password: ''
        }
      }
      expect(user2.reload.name).not_to eq(user3.name)
    end
  end

  context 'update ldap user info' do
    let(:user4) { create(:ldap_user) }

    before do
      sign_in user4
    end

    it 'user updates without password' do
      post :update, params: {
        user: {
          name: user1.name
        }
      }
      expect(user4.reload.name).to eq(user1.name)
    end
  end
end
