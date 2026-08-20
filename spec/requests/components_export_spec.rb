# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component bulk export' do
  include_context 'components request base setup'

  # ==========================================================================
  # REQUIREMENT: Bulk component export must work for released components
  # shown on the ProjectComponents page. The URL pattern must not collide
  # with the single-component export route /components/:id/export/:type.
  # See: docs/site/disa-process/export-requirements.md Gap 7
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

  # ==========================================================================
  # REQUIREMENT: the xccdf export type is kind-routed — an SRG component
  # exports its authored requirements through the published-SRG mode
  # (never the STIG mode, whose Rule association is structurally empty
  # for SRG kind and would download an empty benchmark).
  # ==========================================================================
  describe 'GET /components/:id/export/xccdf for an SRG component' do
    let_it_be(:export_core) do
      create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-EXPRT', version: 'V1R1')
    end
    let_it_be(:export_core_row) do
      create(:srg_rule, security_requirements_guide: export_core, version: 'SRG-OS-000821')
    end
    let_it_be(:srg_component) do
      srg_comp = Component.create!(project: project, name: 'Export SRG Component', prefix: 'EXPS-00',
                                   title: 'Export SRG', document_type: 'srg', based_on: export_core)
      srg_comp.authored_srg_rules.each { |r| r.update!(status: 'Applicable', audit_comment: 'setup') }
      ReleaseIdentifierMinter.new(srg_comp).mint!(srg_comp.authored_srg_rules.to_a)
      srg_comp
    end

    it 'serves the published SRG shape — authored requirements with minted identifiers' do
      get "/components/#{srg_component.id}/export/xccdf", headers: { 'Accept' => 'text/html' }

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to include('application/xml')
      expect(response.body).to include('SRG-OS-000821-EXPS-000001')
      expect(response.body).to include('GroupDescription')
    end
  end

  # ==========================================================================
  # REQUIREMENT (kind routing): bulk exports serve both document kinds
  # through the same seam as project exports — xccdf kind-routes each
  # component; purposes with no srg meaning exclude srg components, and an
  # all-excluded selection refuses loudly.
  # ==========================================================================
  describe 'GET /components/bulk_export/:type kind routing' do
    let_it_be(:bulk_core) do
      create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-BLKX', version: 'V1R1')
    end
    let_it_be(:bulk_core_row) do
      create(:srg_rule, security_requirements_guide: bulk_core, version: 'SRG-OS-000822')
    end
    let_it_be(:released_srg) do
      comp = Component.create!(project: project, name: 'Bulk SRG Component', prefix: 'BLKS-00',
                               title: 'Bulk SRG', document_type: 'srg', based_on: bulk_core)
      comp.authored_srg_rules.each do |r|
        r.update!(status: 'Applicable', locked: true, audit_comment: 'bulk export setup')
      end
      comp.via_release_flow = true
      comp.update!(released: true)
      comp
    end
    let_it_be(:released_stig) { create(:component, project: project, released: true) }

    it 'bulk xccdf kind-routes the srg component alongside the stig one in one archive' do
      get "/components/bulk_export/xccdf?component_ids=#{released_srg.id},#{released_stig.id}",
          headers: { 'Accept' => 'text/html' }
      expect(response).to have_http_status(:success)

      entries = {}
      Zip::File.open_buffer(StringIO.new(response.body)) do |zip|
        zip.each { |e| entries[e.name] = zip.read(e.name) }
      end

      srg_entry = entries.keys.find { |n| n.start_with?('BLKS-00') }
      expect(srg_entry).to be_present, "srg member missing: #{entries.keys}"
      srg_doc = Nokogiri::XML(entries[srg_entry])
      expect(srg_doc.css('Group').size).to eq(1)
      expect(entries[srg_entry]).to include('GroupDescription')

      stig_entry = entries.keys.find { |n| n.start_with?(released_stig.prefix) }
      expect(stig_entry).to be_present
    end

    it 'refuses a bulk inspec export when every selected component is srg' do
      get "/components/bulk_export/inspec?component_ids=#{released_srg.id}",
          headers: { 'Accept' => 'text/html' }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
