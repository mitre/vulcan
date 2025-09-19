# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users', type: :request do
  before do
    Rails.application.reload_routes!
  end

  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  let(:target_user) { create(:user, admin: false) }

  describe 'PUT /users/:id HTML format with admin user' do
    before { sign_in admin_user }

    let(:valid_params) { { user: { admin: true } } }

    it 'updates the user and redirects to index' do
      put "/users/#{target_user.id}", params: valid_params

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(users_path)

      target_user.reload
      expect(target_user.admin).to be true
    end

    it 'sets success flash message' do
      put "/users/#{target_user.id}", params: valid_params

      follow_redirect!
      expect(flash[:notice]).to eq('Successfully updated user.')
    end

    it 'sends slack notification when enabled' do
      allow(Settings.slack).to receive(:enabled).and_return(true)
      expect_any_instance_of(UsersController).to receive(:send_slack_notification)
        .with(:assign_vulcan_admin, target_user)

      put "/users/#{target_user.id}", params: valid_params
    end
  end

  describe 'PUT /users/:id JSON format with admin user' do
    before { sign_in admin_user }

    let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }
    let(:valid_params) { { user: { admin: true } } }

    it 'updates the user and returns success JSON' do
      put "/users/#{target_user.id}", params: valid_params.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')

      json_response = response.parsed_body
      expect(json_response['toast']).to eq('Successfully updated user')

      target_user.reload
      expect(target_user.admin).to be true
    end

    it 'does not set flash messages for JSON requests' do
      put "/users/#{target_user.id}", params: valid_params.to_json, headers: json_headers

      expect(flash).to be_empty
    end
  end

  describe 'PUT /users/:id with non-admin user' do
    before { sign_in regular_user }

    it 'redirects with authorization error' do
      put "/users/#{target_user.id}", params: { user: { admin: true } }

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(flash[:alert]).to include('Please contact an administrator if you believe this message is in error')
    end
  end

  describe 'PUT /users/:id when not authenticated' do
    it 'redirects to login page' do
      put "/users/#{target_user.id}", params: { user: { admin: true } }

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'format handling regression prevention' do
    before { sign_in admin_user }

    it 'properly handles mixed HTML/JSON requests' do
      # Test that HTML requests get HTML responses
      put "/users/#{target_user.id}", params: { user: { admin: true } }
      expect(response).to have_http_status(:redirect)

      # Test that JSON requests get JSON responses
      json_headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
      put "/users/#{target_user.id}", params: { user: { admin: false } }.to_json, headers: json_headers
      expect(response.content_type).to include('application/json')
    end
  end
end
