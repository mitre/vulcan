# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::OmniauthCallbacksController, type: :controller do
  include LoginHelpers

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
  end

  describe 'error handling' do
    describe '#oauth_error' do
      it 'handles Rack::OAuth2::Client::Error' do
        error = Rack::OAuth2::Client::Error.new('OAuth client error')

        expect(Rails.logger).to receive(:error).with(/OAuth authentication error/)

        get :oidc
        controller.send(:oauth_error, error)

        expect(flash[:alert]).to eq('OAuth error: OAuth client error')
        expect(response).to redirect_to(root_path)
      end
    end

    describe '#omniauth_callback_error' do
      it 'handles OmniAuth callback errors with user-friendly message' do
        error = StandardError.new('Callback failed')
        error.define_singleton_method(:class) { OmniAuth::Strategies::OAuth2::CallbackError }

        expect(Rails.logger).to receive(:error).with(/OmniAuth callback error/)

        get :oidc
        controller.send(:omniauth_callback_error, error)

        expect(flash[:alert]).to eq('Authentication failed. Please try again or contact your administrator.')
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe '#omniauth_timeout_error' do
      it 'handles timeout errors' do
        error = Timeout::Error.new('Request timed out')

        expect(Rails.logger).to receive(:error).with(/OmniAuth timeout error/)

        get :oidc
        controller.send(:omniauth_timeout_error, error)

        expect(flash[:alert]).to eq('Authentication timed out. Please try again.')
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'handles Faraday timeout errors' do
        error = Faraday::TimeoutError.new('Faraday timeout')

        expect(Rails.logger).to receive(:error).with(/OmniAuth timeout error/)

        get :oidc
        controller.send(:omniauth_timeout_error, error)

        expect(flash[:alert]).to eq('Authentication timed out. Please try again.')
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe '#omniauth_validation_error' do
      it 'handles validation errors with specific message' do
        error = ArgumentError.new('Email is required but was not found')

        expect(Rails.logger).to receive(:error).with(/OmniAuth validation error/)

        get :oidc
        controller.send(:omniauth_validation_error, error)

        expect(flash[:alert]).to eq('Authentication failed: Email is required but was not found')
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe '#omniauth_record_error' do
      it 'handles database record errors' do
        error = ActiveRecord::RecordInvalid.new(User.new)

        expect(Rails.logger).to receive(:error).with(/OmniAuth database error/)

        get :oidc
        controller.send(:omniauth_record_error, error)

        expect(flash[:alert]).to eq('Account creation failed. Please contact your administrator.')
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe '#omniauth_generic_error' do
      it 'handles unexpected errors gracefully' do
        error = StandardError.new('Unexpected error')

        expect(Rails.logger).to receive(:error).with(/Unexpected OmniAuth error/)

        get :oidc
        controller.send(:omniauth_generic_error, error)

        expect(flash[:alert]).to eq('An unexpected error occurred during authentication. Please try again.')
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'rescue_from integration' do
    before do
      # Mock the omniauth environment
      request.env['omniauth.auth'] = mock_omniauth_response(build(:user))
    end

    it 'rescues ArgumentError and calls omniauth_validation_error' do
      allow(User).to receive(:from_omniauth).and_raise(ArgumentError.new('Test validation error'))

      expect(controller).to receive(:omniauth_validation_error)

      get :oidc
    end

    it 'rescues ActiveRecord::RecordInvalid and calls omniauth_record_error' do
      allow(User).to receive(:from_omniauth).and_raise(ActiveRecord::RecordInvalid.new(User.new))

      expect(controller).to receive(:omniauth_record_error)

      get :oidc
    end

    it 'rescues Timeout::Error and calls omniauth_timeout_error' do
      allow(User).to receive(:from_omniauth).and_raise(Timeout::Error.new('Timeout'))

      expect(controller).to receive(:omniauth_timeout_error)

      get :oidc
    end

    it 'rescues StandardError and calls omniauth_generic_error' do
      allow(User).to receive(:from_omniauth).and_raise(StandardError.new('Generic error'))

      expect(controller).to receive(:omniauth_generic_error)

      get :oidc
    end
  end

  describe 'successful authentication flow' do
    it 'processes successful authentication without errors' do
      user = create(:user)
      auth = mock_omniauth_response(user)

      request.env['omniauth.auth'] = auth
      allow(User).to receive(:from_omniauth).with(auth).and_return(user)

      get :oidc

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq(I18n.t('devise.sessions.signed_in'))
    end

    it 'stores ID token in session for OIDC logout' do
      user = create(:user)
      auth = mock_omniauth_response(user)
      auth.credentials.id_token = 'mock_id_token'

      request.env['omniauth.auth'] = auth
      allow(User).to receive(:from_omniauth).with(auth).and_return(user)

      get :oidc

      expect(session[:id_token]).to eq('mock_id_token')
    end

    it 'warns when ID token is missing' do
      user = create(:user)
      auth = mock_omniauth_response(user)
      auth.credentials.id_token = nil

      request.env['omniauth.auth'] = auth
      allow(User).to receive(:from_omniauth).with(auth).and_return(user)

      expect(Rails.logger).to receive(:warn).with(/No ID token in OmniAuth credentials/)

      get :oidc
    end
  end

  describe 'logging integration' do
    it 'logs successful authentication details' do
      user = create(:user)
      auth = mock_omniauth_response(user)

      request.env['omniauth.auth'] = auth
      allow(User).to receive(:from_omniauth).with(auth).and_return(user)

      expect(Rails.logger).to receive(:info).with(/OmniAuth callback received for provider/)
      expect(Rails.logger).to receive(:info).with(/Stored ID token in session for user/)

      get :oidc
    end

    it 'includes debug information in development environment' do
      allow(Rails.env).to receive(:development?).and_return(true)

      error = StandardError.new('Test error')
      allow(error).to receive(:backtrace).and_return(%w[line1 line2])

      expect(Rails.logger).to receive(:error).with(/Unexpected OmniAuth error/)
      expect(Rails.logger).to receive(:debug).with("line1\nline2")

      get :oidc
      controller.send(:omniauth_generic_error, error)
    end
  end
end
