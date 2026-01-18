# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::BaseController, type: :controller do
  # Create a test controller that inherits from Api::BaseController
  controller(Api::BaseController) do
    before_action :authenticate_user!, only: [:require_auth]
    before_action :set_resource, only: [:check_not_found]
    before_action :authorize_action, only: [:check_forbidden]

    def no_auth_needed
      render json: { message: 'success' }
    end

    def require_auth
      render json: { message: 'authenticated' }
    end

    def check_parameter_missing
      params.require(:required_param)
      render json: { message: 'has required param' }
    end

    def check_not_found
      render json: { resource: @resource }
    end

    def check_forbidden
      render json: { message: 'authorized' }
    end

    private

    def set_resource
      @resource = User.find(params[:id])
    end

    def authorize_action
      raise NotAuthorizedError, 'You are not authorized to perform this action'
    end
  end

  before do
    # Define routes for the test controller
    routes.draw do
      get 'no_auth_needed' => 'api/base#no_auth_needed'
      get 'require_auth' => 'api/base#require_auth'
      post 'check_parameter_missing' => 'api/base#check_parameter_missing'
      get 'check_not_found/:id' => 'api/base#check_not_found'
      get 'check_forbidden' => 'api/base#check_forbidden'
    end
  end

  describe 'skip_before_action' do
    it 'skips setup_navigation' do
      get :no_auth_needed, format: :json
      expect(response).to have_http_status(:ok)
      # If setup_navigation ran, it would redirect unauthenticated users
    end

    it 'skips check_access_request_notifications' do
      get :no_auth_needed, format: :json
      expect(response).to have_http_status(:ok)
      # If check_access_request_notifications ran, it would set instance variables
    end
  end

  describe 'rescue_from ActionController::ParameterMissing' do
    it 'returns 400 Bad Request with error message' do
      post :check_parameter_missing, format: :json

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['error']).to include('required_param')
    end
  end

  describe 'rescue_from ActiveRecord::RecordNotFound' do
    it 'returns 404 Not Found with error message' do
      get :check_not_found, params: { id: 999_999 }, format: :json

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['error']).to eq('Not found')
    end
  end

  describe 'rescue_from NotAuthorizedError' do
    let(:user) { create(:user) }

    before { sign_in user }

    it 'returns 403 Forbidden with error message' do
      get :check_forbidden, format: :json

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json['error']).to eq('You are not authorized to perform this action')
    end

    it 'does not return 401 Unauthorized' do
      get :check_forbidden, format: :json

      expect(response).not_to have_http_status(:unauthorized)
    end
  end

  describe 'JSON responses' do
    it 'returns JSON for errors' do
      post :check_parameter_missing, format: :json

      expect(response.content_type).to include('application/json')
    end
  end
end
