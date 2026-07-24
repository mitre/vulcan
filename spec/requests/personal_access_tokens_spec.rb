# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PersonalAccessTokens management' do
  include Devise::Test::IntegrationHelpers

  before { Rails.application.reload_routes! }

  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:user) { create(:user, admin: false, password: 'PAToken99!!test') }

  describe 'POST /personal_access_tokens (create)' do
    before { sign_in user }

    it 'creates a token and returns the raw token once' do
      post '/personal_access_tokens',
           params: {
             personal_access_token: {
               name: 'My CI Token',
               scopes: %w[read write],
               expires_at: 30.days.from_now.to_date.to_s,
               current_password: 'PAToken99!!test'
             }
           },
           headers: { 'Accept' => 'application/json' },
           as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['token']).to start_with('vulcan_')
      expect(body['personal_access_token']['name']).to eq('My CI Token')
      expect(body['personal_access_token']['scopes']).to eq(%w[read write])
      expect(body['personal_access_token']['token_prefix']).to start_with('vulcan_')
      expect(body['personal_access_token']).not_to have_key('token_digest')
    end

    it 'rejects creation with wrong password' do
      post '/personal_access_tokens',
           params: {
             personal_access_token: {
               name: 'Bad password',
               scopes: %w[read],
               current_password: 'wrong_password'
             }
           },
           headers: { 'Accept' => 'application/json' },
           as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['type']).to eq('/api/docs/errors#incorrect_password')
      expect(response.parsed_body['detail']).to include('password')
    end

    it 'rejects creation without password' do
      post '/personal_access_tokens',
           params: {
             personal_access_token: {
               name: 'No password',
               scopes: %w[read]
             }
           },
           headers: { 'Accept' => 'application/json' },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects invalid scopes' do
      post '/personal_access_tokens',
           params: {
             personal_access_token: {
               name: 'Bad scopes',
               scopes: %w[read hack],
               current_password: 'PAToken99!!test'
             }
           },
           headers: { 'Accept' => 'application/json' },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'creates a token with IP allowlist' do
      post '/personal_access_tokens',
           params: {
             personal_access_token: {
               name: 'IP restricted',
               scopes: %w[read],
               allowed_ips: ['10.0.0.0/8'],
               current_password: 'PAToken99!!test'
             }
           },
           headers: { 'Accept' => 'application/json' },
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['personal_access_token']['allowed_ips']).to eq(['10.0.0.0/8'])
    end
  end

  # REQUIREMENT (non-repudiation): a personal access token authenticates AS
  # its owner, so it may only ever be minted for the signed-in account. No
  # request shape — not an admin's, not any parameter placement — may
  # redirect ownership to another user. Admin oversight of someone else's
  # tokens is READ and REVOKE only (listing below, and the admin revoke
  # endpoint); minting on their behalf would make every audit record
  # attributed to that user repudiable. Accountable admin recovery already
  # exists via password reset, where the user re-authenticates and the admin
  # never holds a credential that speaks as them.
  describe 'token ownership cannot be redirected (non-repudiation)' do
    let_it_be(:admin_pw) { 'PAToken99!!admin' }
    let_it_be(:pw_admin) { create(:user, admin: true, password: admin_pw) }
    let_it_be(:target) { create(:user, admin: false) }

    it 'creates the token on the admin\'s own account when user_id is sent top-level' do
      sign_in pw_admin

      post '/personal_access_tokens',
           params: {
             user_id: target.id,
             personal_access_token: { name: 'On behalf attempt', scopes: %w[read],
                                      current_password: admin_pw }
           },
           headers: { 'Accept' => 'application/json' }, as: :json

      expect(response).to have_http_status(:created)
      token = PersonalAccessToken.find_by!(name: 'On behalf attempt')
      expect(token.user_id).to eq(pw_admin.id)
      expect(target.personal_access_tokens).to be_empty
    end

    it 'creates the token on the admin\'s own account when user_id is nested in the payload' do
      sign_in pw_admin

      post '/personal_access_tokens',
           params: {
             personal_access_token: { name: 'Nested attempt', scopes: %w[read],
                                      user_id: target.id, current_password: admin_pw }
           },
           headers: { 'Accept' => 'application/json' }, as: :json

      expect(response).to have_http_status(:created)
      token = PersonalAccessToken.find_by!(name: 'Nested attempt')
      expect(token.user_id).to eq(pw_admin.id)
      expect(target.personal_access_tokens).to be_empty
    end

    it 'creates the token on a non-admin\'s own account when user_id is supplied' do
      sign_in user

      post '/personal_access_tokens',
           params: {
             user_id: target.id,
             personal_access_token: { name: 'Non-admin attempt', scopes: %w[read],
                                      current_password: 'PAToken99!!test' }
           },
           headers: { 'Accept' => 'application/json' }, as: :json

      expect(response).to have_http_status(:created)
      token = PersonalAccessToken.find_by!(name: 'Non-admin attempt')
      expect(token.user_id).to eq(user.id)
      expect(target.personal_access_tokens).to be_empty
    end
  end

  describe 'GET /personal_access_tokens (index)' do
    before { sign_in user }

    it 'lists the current user tokens without exposing digests' do
      create(:personal_access_token, user: user, name: 'Token A')
      create(:personal_access_token, user: user, name: 'Token B')

      get '/personal_access_tokens', headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['personal_access_tokens'].length).to eq(2)
      names = body['personal_access_tokens'].pluck('name')
      expect(names).to contain_exactly('Token A', 'Token B')

      body['personal_access_tokens'].each do |t|
        expect(t).not_to have_key('token_digest')
        expect(t).to have_key('token_prefix')
        expect(t).to have_key('scopes')
        expect(t).to have_key('last_used_at')
        expect(t).to have_key('expires_at')
      end
    end

    it 'does not show other users tokens' do
      create(:personal_access_token, user: admin, name: 'Admin Token')

      get '/personal_access_tokens', headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      names = response.parsed_body['personal_access_tokens'].pluck('name')
      expect(names).not_to include('Admin Token')
    end
  end

  # REQUIREMENT (admin oversight — the counterpart to the minting ban above):
  # an admin may LIST another user's tokens, seeing owner identity and usage
  # metadata but never the secret. This is how oversight stays possible
  # without anyone holding a credential that speaks as someone else.
  describe 'GET /personal_access_tokens?user_id= (admin oversight)' do
    it 'lists another user\'s tokens with owner identity, never the secret' do
      create(:personal_access_token, user: user, name: 'Owned by user')
      sign_in admin

      get '/personal_access_tokens', params: { user_id: user.id },
                                     headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      rows = response.parsed_body['personal_access_tokens']
      expect(rows.pluck('name')).to include('Owned by user')
      row = rows.find { |r| r['name'] == 'Owned by user' }
      expect(row['user_id']).to eq(user.id)
      expect(row['user_email']).to eq(user.email)
      expect(row).to have_key('token_prefix')
      expect(row).not_to have_key('token_digest')
    end

    it 'ignores user_id for a non-admin — they still see only their own' do
      create(:personal_access_token, user: admin, name: 'Admin Only Token')
      create(:personal_access_token, user: user, name: 'Own Token')
      sign_in user

      get '/personal_access_tokens', params: { user_id: admin.id },
                                     headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      names = response.parsed_body['personal_access_tokens'].pluck('name')
      expect(names).to include('Own Token')
      expect(names).not_to include('Admin Only Token')
    end
  end

  describe 'DELETE /personal_access_tokens/:id (revoke)' do
    before { sign_in user }

    it 'revokes the token' do
      token = create(:personal_access_token, user: user)

      delete "/personal_access_tokens/#{token.id}",
             headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['toast']['variant']).to eq('success')
      expect(token.reload.revoked_at).to be_present
    end

    it 'cannot revoke another users token' do
      admin_token = create(:personal_access_token, user: admin)

      delete "/personal_access_tokens/#{admin_token.id}",
             headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:not_found)
      expect(admin_token.reload.revoked_at).to be_nil
    end
  end

  describe 'admin revocation' do
    before { sign_in admin }

    it 'admin can revoke any users token via admin endpoint' do
      user_token = create(:personal_access_token, user: user)

      delete "/personal_access_tokens/#{user_token.id}/admin_revoke",
             params: { audit_comment: 'Compromised credentials' },
             headers: { 'Accept' => 'application/json' },
             as: :json

      expect(response).to have_http_status(:ok)
      expect(user_token.reload.revoked_at).to be_present
    end

    it 'non-admin cannot use admin revoke endpoint' do
      sign_in user
      token = create(:personal_access_token, user: user)

      delete "/personal_access_tokens/#{token.id}/admin_revoke",
             params: { audit_comment: 'test' },
             headers: { 'Accept' => 'application/json' },
             as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'feature toggle' do
    before { sign_in user }

    it 'returns 404 when api_tokens.enabled is false' do
      allow(Settings).to receive_message_chain(:api_tokens, :enabled).and_return(false)

      get '/personal_access_tokens', headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'authentication required' do
    it 'redirects unauthenticated users' do
      get '/personal_access_tokens'
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'rejects API token auth for management endpoints (session only)' do
      token = create(:personal_access_token, user: user, scopes: %w[admin])

      get '/personal_access_tokens',
          headers: { 'Authorization' => "Token #{token.raw_token}", 'Accept' => 'application/json' }

      # Management endpoints should reject token auth — session only
      expect(response).to have_http_status(:forbidden)
    end
  end
end
