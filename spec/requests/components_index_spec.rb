# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component index' do
  include_context 'components request base setup'

  describe 'GET /components (Jbuilder optimization)' do
    let!(:released_component) do
      comp = create(:component, project: project, released: true)
      comp.reload
      comp
    end
    let!(:unreleased_component) { create(:component, project: project, released: false) }

    it_behaves_like 'jbuilder index', {
      path: '/components',
      factory: :component,
      required_fields: %w[id name version release prefix updated_at based_on_title based_on_version],
      excluded_fields: %w[rules reviews memberships histories metadata]
    }

    it 'only returns released components' do
      get '/components', headers: { 'Accept' => application_json }

      json = response.parsed_body
      ids = json.pluck('id')

      expect(ids).to include(released_component.id)
      expect(ids).not_to include(unreleased_component.id)
    end

    context 'when unauthenticated' do
      before { sign_out user }

      it 'redirects to sign-in' do
        get '/components', headers: { 'Accept' => application_json }
        expect(response).to have_http_status(:unauthorized)
          .or redirect_to(new_user_session_path)
      end
    end
  end
end
