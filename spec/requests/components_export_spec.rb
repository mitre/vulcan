# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component bulk export' do
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

    context 'when unauthenticated' do
      before { sign_out user }

      it 'redirects to sign-in' do
        get "/components/bulk_export/csv?component_ids=#{released.id}"
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
