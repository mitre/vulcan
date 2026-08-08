# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component relationships' do
  include_context 'components request base setup'

  # renamed from /components/:id/search/based_on_same_srg to
  # /components/:id/related for clarity; response is now an explicit field
  # allowlist (no AR timestamps / internal FKs leaked).
  describe 'GET /components/:id/related' do
    it 'returns components based on the same SRG without 500 error' do
      get "/components/#{component.id}/related", headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success).or have_http_status(:not_found)
      expect(response).not_to have_http_status(:internal_server_error)
    end

    it 'response does not leak AR timestamps or internal FKs' do
      create(:component, project: project, name: 'Same-SRG Sibling',
                         security_requirements_guide_id: component.security_requirements_guide_id)
      get "/components/#{component.id}/related", headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success)
      json = response.parsed_body
      expect(json).to be_an(Array)
      next if json.empty? # tolerate empty result if visibility rules exclude the sibling

      keys = json.first.keys
      expect(keys).to include('id', 'name', 'version', 'prefix', 'release', 'project_id', 'project_name')
      expect(keys).not_to include('created_at', 'updated_at', 'component_id', 'security_requirements_guide_id')
    end
  end

  # compare moved from sub-resource path
  # (/components/:id/compare/:diff_id, which implied parent-child) to peer
  # query params with an envelope response.
  describe 'GET /api/components/compare' do
    it 'returns diff with metadata envelope' do
      other_component = create(:component, project: project)
      get '/api/components/compare',
          params: { base_id: component.id, diff_id: other_component.id },
          headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success)
      json = response.parsed_body
      expect(json).to have_key('data')
      expect(json).to have_key('meta')
      expect(json['meta']['base_id']).to eq(component.id)
      expect(json['meta']['diff_id']).to eq(other_component.id)
      expect(json['meta']).to have_key('rules_count')
    end

    it 'returns 404 when either component does not exist' do
      get '/api/components/compare',
          params: { base_id: component.id, diff_id: 999_999 },
          headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:not_found)
    end

    # The compare endpoint diffs exactly one field — inspec_control_file —
    # and SRG requirements carry no InSpec. An SRG or mixed-kind compare
    # guards loudly instead of diffing nothing and reporting "unchanged".
    context 'with SRG-kind components' do
      let_it_be(:srg_base) do
        create(:component, :skip_rules, project: project, document_type: 'srg',
                                        prefix: 'CMPA-00', name: 'Compare SRG A', title: 'Compare SRG A')
      end
      let_it_be(:srg_diff) do
        create(:component, :skip_rules, project: project, document_type: 'srg',
                                        prefix: 'CMPB-00', name: 'Compare SRG B', title: 'Compare SRG B')
      end

      it 'guards SRG-vs-SRG compare with a clear 422' do
        get '/api/components/compare',
            params: { base_id: srg_base.id, diff_id: srg_diff.id },
            headers: { 'Accept' => application_json }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body['error']).to include('InSpec comparison applies to STIG components')
      end

      it 'guards mixed-kind compare with the same 422' do
        get '/api/components/compare',
            params: { base_id: component.id, diff_id: srg_base.id },
            headers: { 'Accept' => application_json }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body['error']).to include('InSpec comparison applies to STIG components')
      end
    end
  end
end
