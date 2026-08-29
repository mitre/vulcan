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
  # per-component route). The WORKING COPY serves both kinds directly — SRGs
  # and STIGs are XCCDF documents authored the same way, so csv/excel carry
  # srg components rather than skipping them. Purposes with no srg meaning
  # (inspec, vendor submission) EXCLUDE srg components from the output —
  # never a silently empty archive member. An export whose every component
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

    it 'project xccdf export renders the srg component through the published_srg mode' do
      get "/projects/#{project.id}/export/xccdf", headers: { 'Accept' => 'text/html' }
      expect(response).to have_http_status(:success)

      names = zip_entries(response.body)
      srg_entry = names.find { |n| n.start_with?('PXPT-00') }
      expect(srg_entry).to be_present, "srg member missing from archive: #{names}"

      srg_xml = zip_read(response.body, srg_entry)
      expect(Nokogiri::XML(srg_xml).css('Group').size).to eq(1)
      expect(srg_xml).to include('Exportable authored requirement')

      # The stig component still exports through its own mode in the same archive.
      expect(names.find { |n| n.start_with?(component.prefix) }).to be_present
    end

    it 'serves the srg component in the project csv export' do
      get "/projects/#{project.id}/export/csv", headers: { 'Accept' => 'text/html' }
      expect(response).to have_http_status(:success)

      # The working copy has srg meaning, so BOTH components produce a CSV and
      # Packager zips the pair — the srg member carries its authored
      # requirement rather than being dropped from the run.
      names = zip_entries(response.body)
      srg_entry = names.find { |n| n.include?('PXPT-00') }
      expect(srg_entry).to be_present, "srg member missing from archive: #{names}"
      expect(zip_read(response.body, srg_entry)).to include('Exportable authored requirement')

      expect(names.find { |n| n.include?(component.prefix) }).to be_present
    end

    it 'excludes the srg component from the project inspec export' do
      get "/projects/#{project.id}/export/inspec", headers: { 'Accept' => 'text/html' }
      expect(response).to have_http_status(:success)

      # InSpec batch archives name entries by component NAME directory,
      # not prefix — grep the directory the srg component would get.
      names = zip_entries(response.body)
      expect(names.grep(/Project-Export-SRG/)).to be_empty
      expect(names.grep(/#{component.name.tr(' ', '-')}/)).not_to be_empty
    end

    it 'refuses loudly when every selected component is excluded by the purpose' do
      # vendor_submission is the purpose with no srg meaning now that the
      # working copy serves both kinds.
      get "/projects/#{project.id}/export/excel?mode=vendor_submission&component_ids=#{srg_component.id}",
          headers: { 'Accept' => 'text/html' }

      expect(response).to have_http_status(:unprocessable_content)
      # Pin the reason: a 422 from any other guard must not satisfy this.
      expect(response.body).to include('None of the selected components support this export purpose.')
    end
  end
end
