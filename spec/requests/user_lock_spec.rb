# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /users/:id/lock' do
  let!(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  let(:target_user) { create(:user, admin: false) }
  let(:json_headers) { { 'Accept' => 'application/json' } }

  before do
    Rails.application.reload_routes!
  end

  context 'when not authenticated' do
    it 'redirects to login' do
      post "/users/#{target_user.id}/lock"
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'when non-admin' do
    before { sign_in regular_user }

    it 'blocks access' do
      post "/users/#{target_user.id}/lock"
      expect(response).to redirect_to(root_path)
    end
  end

  context 'when admin' do
    before { sign_in admin_user }

    it 'locks the user' do
      post "/users/#{target_user.id}/lock", headers: json_headers

      expect(response).to have_http_status(:ok)
      target_user.reload
      expect(target_user.access_locked?).to be true
    end

    it 'returns success JSON' do
      post "/users/#{target_user.id}/lock", headers: json_headers

      json = response.parsed_body
      expect(json['toast']).to include('locked')
    end

    it 'returns user data with lock fields' do
      post "/users/#{target_user.id}/lock", headers: json_headers

      json = response.parsed_body
      expect(json['user']).to include('id', 'failed_attempts', 'locked_at')
      expect(json['user']['locked_at']).not_to be_nil
    end

    it 'is idempotent on already-locked user' do
      target_user.lock_access!

      post "/users/#{target_user.id}/lock", headers: json_headers

      expect(response).to have_http_status(:ok)
    end

    it 'prevents locking yourself' do
      post "/users/#{admin_user.id}/lock", headers: json_headers

      expect(response).to have_http_status(:unprocessable_entity)
      admin_user.reload
      expect(admin_user.access_locked?).to be false
    end
  end
end
