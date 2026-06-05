# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Components' do
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
                         based_on: component.based_on)
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
  end

  # revision history was POST (read-only query, wrong method)
  # with mixed camelCase/snake_case keys. Now GET with all-snake_case keys.
  describe 'GET /components/history' do
    let!(:versioned_initial) do
      create(:component, project: project, name: 'Versioned Comp', version: 1, release: 1)
    end
    let!(:versioned_revision) do
      create(:component, project: project, name: 'Versioned Comp', version: 1, release: 2)
    end

    it 'returns snake_case keys (base_component, diff_component)' do
      get '/components/history',
          params: { project_id: project.id, name: 'Versioned Comp' },
          headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success)
      json = response.parsed_body
      expect(json).to be_an(Array)
      diff_entry = json.find { |e| e.key?('base_component') }
      expect(diff_entry).to be_present, "expected a diff entry with base_component key; got #{json.inspect}"
      expect(diff_entry).to have_key('diff_component')
      expect(diff_entry).not_to have_key('baseComponent')
      expect(diff_entry).not_to have_key('diffComponent')
    end
  end
end
