# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT (hybrid, visibility-driven disclosure): when an authenticated
# caller is denied on a project-scoped resource, the response depends on the
# project's own `visibility`:
#
#   * DISCOVERABLE project  → 403 #permission_denied + `admins` (the
#     request-access flow working as designed).
#   * NON-DISCOVERABLE (hidden) project → 404 #not_found with a body
#     BYTE-IDENTICAL to a true miss, concealing existence — no wording,
#     status, or content-type tell that distinguishes a concealed resource
#     from one that never existed.
#
# Instance-global resources (STIGs, SRGs) carry no project visibility and are
# never concealed.
#
# Both denial seams are exercised: the HTML controllers' ApplicationController
# #not_authorized (JSON + HTML) and the Api::BaseController rescue (JSON only).
RSpec.describe 'Authorization disclosure policy (visibility-driven 403 vs 404)' do
  # Created first so it absorbs the first-user-admin promotion
  # (VULCAN_FIRST_USER_ADMIN defaults on in test) — otherwise `user` would be
  # auto-promoted to admin and see every project.
  let_it_be(:seed_admin) { create(:user, admin: true) }
  let_it_be(:user) { create(:user) } # authenticated non-member, non-admin

  let_it_be(:hidden_project) { create(:project, :hidden, :with_admin) }
  let_it_be(:discoverable_project) { create(:project, :discoverable, :with_admin) }
  let_it_be(:hidden_component) { create(:component, :skip_rules, project: hidden_project) }
  let_it_be(:discoverable_component) { create(:component, :skip_rules, project: discoverable_project) }

  # An id that cannot resolve — the endpoint's genuine "not found" response.
  # Concealed-denial responses must equal these exactly.
  let(:missing_id) { 2_000_000_000 }

  before do
    Rails.application.reload_routes!
    sign_in user
  end

  # Compares a concealed-denial response against the true-miss baseline for the
  # SAME endpoint shape: identical status, content-type, and body.
  def expect_identical(concealed:, true_miss:)
    expect(concealed[:status]).to eq(true_miss[:status])
    expect(concealed[:content_type]).to eq(true_miss[:content_type])
    expect(concealed[:body]).to eq(true_miss[:body])
  end

  def capture
    yield
    { status: response.status, content_type: response.media_type, body: response.body }
  end

  describe 'HTML ProjectsController#show (GET /projects/:id)' do
    context 'JSON' do
      it 'conceals a hidden project as a 404 identical to a true miss' do
        true_miss = capture { get "/projects/#{missing_id}", as: :json }
        concealed = capture { get "/projects/#{hidden_project.id}", as: :json }

        expect(concealed[:status]).to eq(404)
        expect(concealed[:content_type]).to eq('application/problem+json')
        expect(concealed[:body]).to include('#not_found')
        expect_identical(concealed: concealed, true_miss: true_miss)
      end

      it 'answers a discoverable project denial with 403 permission_denied + admins' do
        get "/projects/#{discoverable_project.id}", as: :json

        expect(response).to have_http_status(:forbidden)
        expect(response.media_type).to eq('application/problem+json')
        body = response.parsed_body
        expect(body['type']).to eq('/api/docs/errors#permission_denied')
        expect(body['admins']).to be_present
        expect(body['admins'].first).to include('name', 'email')
      end
    end

    context 'HTML' do
      it 'conceals a hidden project as a 404 identical to a true miss' do
        true_miss = capture { get "/projects/#{missing_id}" }
        concealed = capture { get "/projects/#{hidden_project.id}" }

        expect(concealed[:status]).to eq(404)
        expect_identical(concealed: concealed, true_miss: true_miss)
      end

      it 'answers a discoverable project denial with a redirect + flash' do
        get "/projects/#{discoverable_project.id}"

        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'HTML ComponentsController#show (GET /components/:id)' do
    context 'JSON' do
      it 'conceals a component in a hidden project as a 404 identical to a true miss' do
        true_miss = capture { get "/components/#{missing_id}", as: :json }
        concealed = capture { get "/components/#{hidden_component.id}", as: :json }

        expect(concealed[:status]).to eq(404)
        expect(concealed[:content_type]).to eq('application/problem+json')
        expect(concealed[:body]).to include('#not_found')
        expect_identical(concealed: concealed, true_miss: true_miss)
      end

      it 'answers a component in a discoverable project with 403 permission_denied + admins' do
        get "/components/#{discoverable_component.id}", as: :json

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['type']).to eq('/api/docs/errors#permission_denied')
        expect(response.parsed_body['admins']).to be_present
      end
    end

    context 'HTML' do
      it 'conceals a component in a hidden project as a 404 identical to a true miss' do
        true_miss = capture { get "/components/#{missing_id}" }
        concealed = capture { get "/components/#{hidden_component.id}" }

        expect(concealed[:status]).to eq(404)
        expect_identical(concealed: concealed, true_miss: true_miss)
      end
    end

    # A rule deep-link (/components/:id/:stig_id) must not become an existence
    # oracle: rule lookup happens after authorization, so a non-member of a
    # hidden component is concealed before an unknown rule id can produce a
    # distinct not-found (toast on JSON, redirect on HTML).
    context 'rule deep-link (/components/:id/:stig_id) with an unknown rule id' do
      it 'conceals a hidden component (JSON 404 identical to a true miss)' do
        true_miss = capture { get "/components/#{missing_id}/ZZZZ-00-999999", as: :json }
        concealed = capture { get "/components/#{hidden_component.id}/ZZZZ-00-999999", as: :json }

        expect(concealed[:status]).to eq(404)
        expect(concealed[:content_type]).to eq('application/problem+json')
        expect_identical(concealed: concealed, true_miss: true_miss)
      end

      it 'conceals a hidden component (HTML 404 identical to a true miss)' do
        true_miss = capture { get "/components/#{missing_id}/ZZZZ-00-999999" }
        concealed = capture { get "/components/#{hidden_component.id}/ZZZZ-00-999999" }

        expect(concealed[:status]).to eq(404)
        expect_identical(concealed: concealed, true_miss: true_miss)
      end
    end
  end

  describe 'Api::ProjectsController#stats (GET /api/projects/:id/stats)' do
    it 'conceals a hidden project as a 404 identical to a true miss' do
      true_miss = capture { get "/api/projects/#{missing_id}/stats" }
      concealed = capture { get "/api/projects/#{hidden_project.id}/stats" }

      expect(concealed[:status]).to eq(404)
      expect(concealed[:content_type]).to eq('application/problem+json')
      expect_identical(concealed: concealed, true_miss: true_miss)
    end

    it 'answers a discoverable project denial with 403 permission_denied + admins' do
      get "/api/projects/#{discoverable_project.id}/stats"

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['type']).to eq('/api/docs/errors#permission_denied')
      expect(response.parsed_body['admins']).to be_present
    end
  end

  describe 'Api::ComponentsController#summary (GET /api/components/:id/summary)' do
    it 'conceals a component in a hidden project as a 404 identical to a true miss' do
      true_miss = capture { get "/api/components/#{missing_id}/summary" }
      concealed = capture { get "/api/components/#{hidden_component.id}/summary" }

      expect(concealed[:status]).to eq(404)
      expect(concealed[:content_type]).to eq('application/problem+json')
      expect_identical(concealed: concealed, true_miss: true_miss)
    end

    it 'answers a component in a discoverable project with 403 permission_denied + admins' do
      get "/api/components/#{discoverable_component.id}/summary"

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['type']).to eq('/api/docs/errors#permission_denied')
      expect(response.parsed_body['admins']).to be_present
    end
  end

  # A member of a hidden project already knows it exists (it is in their
  # project list), so a role-denial for them is an honest 403 — concealment
  # applies only to callers who cannot otherwise discover the project.
  describe 'members of a hidden project are not concealed from' do
    let_it_be(:hidden_member) { create(:user) }

    before_all do
      create(:membership, :viewer, user: hidden_member, membership: hidden_project)
    end

    it 'answers a viewer member denied an admin action with 403, not a concealing 404' do
      sign_in hidden_member
      put "/projects/#{hidden_project.id}", params: { project: { name: 'Renamed' } }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['type']).to eq('/api/docs/errors#permission_denied')
    end

    it 'still conceals the same hidden project from a non-member (404)' do
      # sign_in `user` (non-member) happens in the outer before
      put "/projects/#{hidden_project.id}", params: { project: { name: 'Renamed' } }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['type']).to eq('/api/docs/errors#not_found')
    end
  end

  # A component-scoped READ endpoint must not become an existence oracle by
  # serving a hidden component to a non-member (it is gated like its siblings).
  describe 'GET /components/:id/related (based_on_same_srg)' do
    it 'conceals a hidden component (JSON 404 identical to a true miss)' do
      true_miss = capture { get "/components/#{missing_id}/related", as: :json }
      concealed = capture { get "/components/#{hidden_component.id}/related", as: :json }

      expect(concealed[:status]).to eq(404)
      expect(concealed[:content_type]).to eq('application/problem+json')
      expect_identical(concealed: concealed, true_miss: true_miss)
    end
  end

  # The project LIST must not disclose non-discoverable projects (or their admin
  # contacts) to a non-member — only member + discoverable projects appear.
  describe 'GET /api/projects (listing scope)' do
    it 'lists a discoverable project but never a hidden non-member project' do
      get '/api/projects', as: :json

      ids = response.parsed_body['rows'].pluck('id')
      expect(ids).to include(discoverable_project.id)
      expect(ids).not_to include(hidden_project.id)
    end
  end

  describe 'instance-global resources are never concealed' do
    it 'serves the global SRG list to any authenticated user (200, not 404)' do
      get '/api/srgs/latest'
      expect(response).to have_http_status(:success)
    end

    it 'serves the global STIG list to any authenticated user (200, not 404)' do
      get '/api/stigs/latest'
      expect(response).to have_http_status(:success)
    end
  end
end
