# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: Project-level CSV export must work alongside existing Excel,
# XCCDF, and InSpec exports. Gap 6 in export-requirements.md — the
# project controller's allowlist omits :csv, so requesting CSV returns 400.
# ==========================================================================
RSpec.describe 'Project Exports' do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }

  before do
    Rails.application.reload_routes!
    sign_in user
    Membership.create!(user: user, membership: project, role: 'viewer')
  end

  describe 'GET /projects/:id/export/csv' do
    it 'exports CSV successfully' do
      get "/projects/#{project.id}/export/csv",
          headers: { 'Accept' => 'text/html' }
      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to include('text/csv')
    end

    it 'includes project name in filename' do
      get "/projects/#{project.id}/export/csv",
          headers: { 'Accept' => 'text/html' }
      expect(response.headers['Content-Disposition']).to include(project.name)
    end
  end

  describe 'GET /projects/:id/export/:type (existing types still work)' do
    it 'rejects unsupported export types' do
      get "/projects/#{project.id}/export/banana",
          headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:bad_request)
    end
  end

  # ==========================================================================
  # REQUIREMENT (kind routing): project exports serve BOTH document kinds.
  # xccdf kind-routes each component (srg -> published_srg, exactly like the
  # per-component route); purposes with no srg meaning (working copy csv,
  # excel, inspec, vendor submission) EXCLUDE srg components from the output
  # — never a silently empty archive member. An export whose every component
  # is excluded refuses loudly instead of producing an empty artifact.
  # ==========================================================================
  describe 'kind routing for SRG components' do
    let_it_be(:srg_component) do
      create(:component, :skip_rules, project: project, document_type: 'srg',
                                      prefix: 'PXPT-00', name: 'Project Export SRG',
                                      title: 'Project Export SRG', version: 1, release: 2)
    end
    let_it_be(:applicable_requirement) do
      create(:srg_rule, :authored, component: srg_component, rule_id: '000001',
                                   status: 'Applicable', title: 'Exportable authored requirement')
    end

    def zip_entries(body)
      entries = {}
      Zip::File.open_buffer(StringIO.new(body)) do |zip|
        zip.each { |e| entries[e.name] = zip.read(e.name) }
      end
      entries
    end

    it 'project xccdf export renders the srg component through the published_srg mode' do
      get "/projects/#{project.id}/export/xccdf", headers: { 'Accept' => 'text/html' }
      expect(response).to have_http_status(:success)

      entries = zip_entries(response.body)
      srg_entry = entries.keys.find { |n| n.start_with?('PXPT-00') }
      expect(srg_entry).to be_present, "srg member missing from archive: #{entries.keys}"

      doc = Nokogiri::XML(entries[srg_entry])
      groups = doc.css('Group')
      expect(groups.size).to eq(1)
      expect(entries[srg_entry]).to include('Exportable authored requirement')

      # The stig component still exports through its own mode in the same archive.
      stig_entry = entries.keys.find { |n| n.start_with?(component.prefix) }
      expect(stig_entry).to be_present
    end

    it 'excludes the srg component from the project csv export with no empty member' do
      get "/projects/#{project.id}/export/csv", headers: { 'Accept' => 'text/html' }
      expect(response).to have_http_status(:success)

      # With the srg component excluded, one CSV remains and Packager passes
      # it through directly (no single-member zip) — the established
      # one-result semantics.
      expect(response.headers['Content-Type']).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include(component.prefix)
      expect(response.headers['Content-Disposition']).not_to include('PXPT')
      expect(response.body).not_to include('Exportable authored requirement')
    end

    it 'excludes the srg component from the project inspec export' do
      get "/projects/#{project.id}/export/inspec", headers: { 'Accept' => 'text/html' }
      expect(response).to have_http_status(:success)

      # InSpec batch archives name entries by component NAME directory,
      # not prefix — grep the directory the srg component would get.
      entries = zip_entries(response.body)
      expect(entries.keys.grep(/Project-Export-SRG/)).to be_empty
      expect(entries.keys.grep(/#{component.name.tr(' ', '-')}/)).not_to be_empty
    end

    it 'refuses loudly when every selected component is excluded by the purpose' do
      get "/projects/#{project.id}/export/csv?component_ids=#{srg_component.id}",
          headers: { 'Accept' => 'text/html' }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
