# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: every JSON auth and
# infrastructure error is an RFC 9457 problem-details body served as
# application/problem+json — a stable machine `type` anchoring into
# /docs/api/errors, a `title` naming the error class, the `status` code
# repeated in the body, an occurrence-specific `detail` saying why, and
# Vulcan help carried as extension members (how_to_authenticate on 401s,
# admins on permission denials). ONE renderer serves Api:: and legacy
# controllers alike — this spec pins closed the defect where
# Api::BaseController shadowed the rich admins-to-ask 403 with a bare body.
RSpec.describe 'API error rendering (RFC 9457 problem details)' do
  before { Rails.application.reload_routes! }

  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:project_admin) { create(:user) }
  let_it_be(:member_viewer) { create(:user) }
  let_it_be(:outsider) { create(:user) }
  # Discoverable so authorization denials answer 403 + admins (the body this
  # spec pins) rather than concealing as 404 — the disclosure policy conceals
  # only non-discoverable projects from strangers.
  let_it_be(:project) { create(:project, :discoverable) }
  let_it_be(:component) do
    create(:component, :skip_rules, project: project, prefix: 'ERRS-01', name: 'Error Rendering Component')
  end

  before_all do
    create(:membership, :admin, user: project_admin, membership: project)
    create(:membership, :viewer, user: member_viewer, membership: project)
  end

  let(:how_to_authenticate) do
    {
      'session' => 'Sign in through the web UI (/users/sign_in) and retry with the session cookie.',
      'token' => 'Create a personal access token (your profile page, or POST /personal_access_tokens) ' \
                 'and send it in the request header: Authorization: Token <your-token>.'
    }
  end

  describe 'permission denied' do
    it 'serves Api:: consumers the full problem body including the admins to ask' do
      sign_in outsider
      get "/api/projects/#{project.id}/stats", as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.media_type).to eq('application/problem+json')
      body = response.parsed_body
      expect(body['type']).to eq('/docs/api/errors#permission_denied')
      expect(body['title']).to eq('Permission denied')
      expect(body['status']).to eq(403)
      expect(body['detail']).to eq('You are not authorized to perform viewer actions on this project')
      expect(body['admins']).to contain_exactly({ 'name' => project_admin.name, 'email' => project_admin.email })
    end

    it 'serves legacy JSON consumers the same problem body plus the legacy toast extension' do
      sign_in member_viewer
      put "/projects/#{project.id}", params: { project: { name: 'Renamed' } }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.media_type).to eq('application/problem+json')
      body = response.parsed_body
      expect(body['type']).to eq('/docs/api/errors#permission_denied')
      expect(body['title']).to eq('Permission denied')
      expect(body['detail']).to eq('You are not authorized to perform administrator actions on this project')
      expect(body['admins']).to contain_exactly({ 'name' => project_admin.name, 'email' => project_admin.email })
      expect(body.dig('toast', 'title')).to eq('Not Authorized.')
      expect(body.dig('toast', 'variant')).to eq('danger')
    end

    it 'keeps the HTML denial flow unchanged (redirect + flash, no problem body)' do
      sign_in member_viewer
      put "/projects/#{project.id}", params: { project: { name: 'Renamed' } }

      expect(response).to have_http_status(:redirect)
      expect(flash.alert).to include('You are not authorized to perform administrator actions on this project')
    end

    it 'routes the disposition-matrix export tier guard through the same body' do
      sign_in member_viewer
      get "/components/#{component.id}/export/disposition_csv", as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.media_type).to eq('application/problem+json')
      body = response.parsed_body
      expect(body['type']).to eq('/docs/api/errors#permission_denied')
      expect(body['detail'])
        .to eq('You are not authorized to export the disposition matrix for this component — author tier or higher is required')
    end
  end

  describe 'not authenticated' do
    it 'explains why and how to authenticate' do
      get "/api/projects/#{project.id}/stats", as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.media_type).to eq('application/problem+json')
      body = response.parsed_body
      expect(body['type']).to eq('/docs/api/errors#not_authenticated')
      expect(body['title']).to eq('Not authenticated')
      expect(body['status']).to eq(401)
      expect(body['detail']).to eq(
        'This request included no API token and no valid signed-in session. If you were signed in, ' \
        'the session may have timed out, been signed out, or ended because this account signed in ' \
        'from another location.'
      )
      expect(body['how_to_authenticate']).to eq(how_to_authenticate)
    end

    it 'names an invalid token and how to fix it' do
      get '/api/auth/me', headers: { 'Authorization' => 'Token vulcan_bogus_token' }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.media_type).to eq('application/problem+json')
      body = response.parsed_body
      expect(body['type']).to eq('/docs/api/errors#invalid_token')
      expect(body['title']).to eq('Invalid or expired API token')
      expect(body['status']).to eq(401)
      expect(body['detail']).to eq(
        'The Authorization header carried a token that does not match any active personal access token. ' \
        'It may be revoked, expired, or mistyped.'
      )
      expect(body['how_to_authenticate']).to eq(how_to_authenticate)
    end

    # Login failure is its own class: the caller is already at the right
    # door, so no how_to_authenticate routing block.
    it 'keeps login failure as its own problem type' do
      post '/api/auth/login', params: { email: outsider.email, password: 'wrong-password' }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.media_type).to eq('application/problem+json')
      body = response.parsed_body
      expect(body['type']).to eq('/docs/api/errors#invalid_credentials')
      expect(body['title']).to eq('Invalid credentials')
      expect(body['detail']).to eq('The email or password is incorrect.')
      expect(body).not_to have_key('how_to_authenticate')
    end

    # 422, not 401: the caller is authenticated and failed the re-verification
    # challenge — a 401 would collide with the client's session-death reload.
    it 'keeps the token-creation password re-check as its own problem type' do
      sign_in member_viewer
      post '/personal_access_tokens',
           params: { personal_access_token: { name: 'probe', scopes: ['read'], current_password: 'wrong' } },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq('application/problem+json')
      body = response.parsed_body
      expect(body['type']).to eq('/docs/api/errors#incorrect_password')
      expect(body['title']).to eq('Incorrect password')
      expect(body['detail']).to eq(
        'Creating or managing API tokens re-verifies your identity, and the current password provided does not match.'
      )
    end
  end

  describe 'token-management and scope denials' do
    it 'explains that token management requires a session' do
      pat = create(:personal_access_token, user: member_viewer, scopes: %w[read write])
      get '/personal_access_tokens', headers: { 'Authorization' => "Token #{pat.raw_token}" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.media_type).to eq('application/problem+json')
      body = response.parsed_body
      expect(body['type']).to eq('/docs/api/errors#session_authentication_required')
      expect(body['title']).to eq('Session authentication required')
      expect(body['detail']).to eq(
        'Token management requires a signed-in browser session; API tokens cannot create or revoke tokens.'
      )
    end
  end

  describe 'not found' do
    it 'serves the problem body on Api:: controllers' do
      sign_in member_viewer
      get '/api/projects/0/stats', as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.media_type).to eq('application/problem+json')
      body = response.parsed_body
      expect(body['type']).to eq('/docs/api/errors#not_found')
      expect(body['title']).to eq('Not found')
      expect(body['status']).to eq(404)
      expect(body['detail']).to eq('The requested resource could not be found.')
    end

    it 'serves the same problem body on legacy JSON requests' do
      sign_in member_viewer
      get '/projects/0', as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.media_type).to eq('application/problem+json')
      body = response.parsed_body
      expect(body['type']).to eq('/docs/api/errors#not_found')
      expect(body['detail']).to eq('The requested resource could not be found.')
    end
  end

  describe 'bad request' do
    it 'names an out-of-range page with the valid range' do
      sign_in member_viewer
      get '/api/projects', params: { page: 9999 }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.media_type).to eq('application/problem+json')
      body = response.parsed_body
      expect(body['type']).to eq('/docs/api/errors#page_out_of_range')
      expect(body['title']).to eq('Page out of range')
      expect(body['status']).to eq(400)
      expect(body['detail']).to match(/\APage 9999 is out of range \(1\.\.\d+\)\z/)
    end
  end

  describe 'the error documentation base resolves to a real page' do
    it 'points every type URI under the docs-site errors page' do
      expect(ErrorRendering::ERROR_DOCS_BASE).to eq('/docs/api/errors')
    end

    it 'documents every emitted error type on the errors page, and only those' do
      # Correspondence guard, both directions: the set of type fragments the
      # app can emit (scanned from the two emitting sources) must equal the
      # set of heading anchors on the docs page. A new render_* without a
      # docs section fails here; so does a docs section for a type that
      # nothing emits.
      emitted = %w[
        app/controllers/concerns/error_rendering.rb
        app/lib/session_aware_failure_app.rb
      ].flat_map { |f| Rails.root.join(f).read.scan(/type: :(\w+)/).flatten }.uniq.sort

      documented = Rails.root.join('docs/site/api/errors.md').read
                        .scan(/^### (\w+)$/).flatten.sort

      expect(emitted).not_to be_empty
      expect(documented).to eq(emitted)
    end

    it 'pins no assertion or contract to the retired error-docs base' do
      # The old base never resolved to a page; after the sweep nothing may
      # still pin it. Pattern built from parts so this guard never matches
      # its own source.
      retired = ['/api/docs', '/errors'].join
      offenders = `git grep -l -F #{Shellwords.escape(retired)} -- app/ spec/ doc/ docs/site config/`.split("\n")
      expect(offenders).to eq([]), "retired error-docs base still pinned in: #{offenders.join(', ')}"
    end
  end
end
