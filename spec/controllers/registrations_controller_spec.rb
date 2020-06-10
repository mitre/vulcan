# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::RegistrationsController, type: :controller do
  include LoginHelpers
  include Users

  before(:each) do
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
      expect(flash[:alert]).to include(I18n.t('devise.registrations.disabled'))
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

  context 'email confirmation enabled' do
    before do
      stub_local_login_setting(email_confirmation: true)
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

      ActionMailer::Base.deliveries.last.tap do |mail|
        expect(mail.from).to eq(['do_not_reply@vulcan'])
      end

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

  context 'empty email' do
    before do
      stub_base_settings(contact_email: 'contact_email@test.com')
      stub_local_login_setting(email_confirmation: true)
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

      ActionMailer::Base.deliveries.last.tap do |mail|
        expect(mail.from).to eq(['contact_email@test.com'])
      end
    end
  end

  context 'update user info' do
    let(:user2) {create(:user)}
    let(:user3) {build(:user)}
    before do 
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
      expect(user2.reload.name).to eq(user3.name)
      user2.reload
      user2.confirm
      expect(user2.email).to eq(user3.email)
      expect(user2.reload.password).to eq(user3.password)
    end
  end

  context 'update user info without password' do
    let(:user2) {create(:user)}
    let(:user3) {build(:user)}
    before do
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
      expect(user2.name).should_not eq(user3.name)
    end
  end

  context 'update ldap user info' do
    let(:user4) {create(:ldap_user)}
    before do
      sign_in user4
    end
    it 'user updates without password' do
      #auth = mock_omniauth_response(user2)
      post :update, params: {
        user: {
          name: user1.name
        }
      }
      expect(user4.reload.name).to eq(user1.name)
    end
  end
end
