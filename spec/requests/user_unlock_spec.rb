# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /users/:id/unlock' do
  let!(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  let(:locked_user) { create(:user, admin: false) }
  let(:json_headers) { { 'Accept' => 'application/json' } }

  before do
    Rails.application.reload_routes!
    locked_user.lock_access!(send_instructions: false)
  end

  context 'when not authenticated' do
    it 'redirects to login' do
      post "/users/#{locked_user.id}/unlock"
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'when non-admin' do
    before { sign_in regular_user }

    it 'blocks access' do
      post "/users/#{locked_user.id}/unlock"
      expect(response).to redirect_to(root_path)
    end
  end

  context 'when admin' do
    before { sign_in admin_user }

    it 'unlocks the user' do
      post "/users/#{locked_user.id}/unlock", headers: json_headers

      expect(response).to have_http_status(:ok)
      locked_user.reload
      expect(locked_user.access_locked?).to be false
    end

    it 'resets failed_attempts' do
      post "/users/#{locked_user.id}/unlock", headers: json_headers

      locked_user.reload
      expect(locked_user.failed_attempts).to eq(0)
    end

    it 'returns success JSON' do
      post "/users/#{locked_user.id}/unlock", headers: json_headers

      json = response.parsed_body
      # canonical {title, message, variant} toast shape.
      expect(json['toast']).to be_a(Hash)
      expect(json['toast']['message'].join).to include('unlocked')
    end

    it 'returns user data with lock fields' do
      post "/users/#{locked_user.id}/unlock", headers: json_headers

      json = response.parsed_body
      expect(json['user']).to include('id', 'failed_attempts', 'locked_at')
      expect(json['user']['locked_at']).to be_nil
      expect(json['user']['failed_attempts']).to eq(0)
    end

    it 'is idempotent on already-unlocked user' do
      unlocked_user = create(:user)

      post "/users/#{unlocked_user.id}/unlock", headers: json_headers

      expect(response).to have_http_status(:ok)
    end
  end
end
