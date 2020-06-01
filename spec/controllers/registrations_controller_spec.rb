# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::RegistrationsController, type: :controller do
  include LoginHelpers

  before(:each) do
    @request.env['devise.mapping'] = Devise.mappings[:user]
  end

  context 'when local login is disabled' do
    before do
      stub_local_login_setting(enabled: false)
    end

    it 'does not allow users to register' do
      post :create, params: {}

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to include(I18n.t('devise.registrations.disabled'))
      expect(User.count).to eq 0
    end
  end

  context 'local login is enabled' do
    before do
      stub_local_login_setting(enabled: true)
    end

    it 'allows users to register' do
      u = build(:user)

      expect do
        post :create, params: {
          user: {
            name: u.name,
            email: u.email,
            password: u.password,
            password_confirmation: u.password
          }
        }
      end.to change(User, :count).by 1

      expect(flash[:notice]).to eq I18n.t('devise.registrations.signed_up_but_unconfirmed')
    end
  end

  context 'email confirmation enabled' do
    before do
      stub_local_login_setting(email_confirmation: true)
    end

    it 'allows users to register' do
      u = build(:user)

      expect do
        post :create, params: {
          user: {
            name: u.name,
            email: u.email,
            password: u.password,
            password_confirmation: u.password
          }
        }
      end.to change(User, :count).by 1

      expect(flash[:notice]).to eq I18n.t('devise.registrations.signed_up_but_unconfirmed')
    end
  end

  context 'email confirmation disabled' do
    before do
      stub_local_login_setting(email_confirmation: false)
    end

    it 'allows users to register without confirming email' do
      u = build(:user)

      expect do
        post :create, params: {
          user: {
            name: u.name,
            email: u.email,
            password: u.password,
            password_confirmation: u.password
          }
        }
      end.to change(User, :count).by 1

      expect(flash[:notice]).to eq I18n.t('devise.registrations.signed_up')
    end
  end

end
