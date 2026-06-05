# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Components' do
  include_context 'components request base setup'

  # ==========================================================================
  # REQUIREMENT: Bulk component export must work for released components
  # shown on the ProjectComponents page. The URL pattern must not collide
  # with the single-component export route /components/:id/export/:type.
  # See: docs/disa-process/export-requirements.md Gap 7
  # ==========================================================================
  describe 'GET /components/bulk_export/:type (ProjectComponents export)' do
    let!(:released) { create(:component, project: project, released: true) }

    it 'exports CSV for selected component IDs' do
      get "/components/bulk_export/csv?component_ids=#{released.id}",
          headers: { 'Accept' => 'text/html' }
      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to include('text/csv')
    end

    it 'exports zip for multiple component IDs' do
      released2 = create(:component, project: project, released: true)
      get "/components/bulk_export/csv?component_ids=#{released.id},#{released2.id}",
          headers: { 'Accept' => 'text/html' }
      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to include('application/zip').or include('application/octet-stream')
    end

    it 'rejects unsupported export types' do
      get "/components/bulk_export/banana?component_ids=#{released.id}",
          headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:bad_request)
    end

    it 'requires component_ids parameter' do
      get '/components/bulk_export/csv',
          headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:bad_request)
    end
  end

  # ==========================================================================
  # REQUIREMENT: Components index should return optimized JSON with only
  # needed fields for table display. Should NOT include heavy fields.
  # ==========================================================================
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
  end
end
