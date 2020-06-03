# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::RegistrationsController, type: :controller do
  include LoginHelpers

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

      expect(flash[:notice]).to eq I18n.t('devise.registrations.signed_up_but_unconfirmed')
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

  context 'default email:' do
    it 'checks if contact email is default' do
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
        expect(mail.from).to eq(["do_not_reply@vulcan"])
      end
    end
  end

  context 'empty email:' do
    before do
      stub_contact_email(contact_email: 'contact_email@test.com')
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

end
