# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT (release endpoint): POST /components/:id/release runs the
# whole SRG release in one transaction — undecided-requirement gate,
# identifier minting, catalog attachment, release copy, released flag —
# behind author-level authorization (the same level that flips released
# via update today). Failures return the canonical toast contract with
# the blocking reasons; success returns the catalog entry and the
# release changelog. A failure ANYWHERE (including the locked-rules
# validation that fires after attachment) leaves no catalog row.
# ==========================================================================
RSpec.describe 'Component release' do
  before do
    Rails.application.reload_routes!
  end

  let_it_be(:core) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-RELEP', version: 'V1R1')
  end
  let_it_be(:core_rows) do
    %w[SRG-OS-000841 SRG-OS-000842].map do |version|
      create(:srg_rule, security_requirements_guide: core, version: version)
    end
  end
  let_it_be(:project) { create(:project) }
  let_it_be(:author) { create(:user) }
  let_it_be(:viewer) { create(:user) }

  before_all do
    create(:membership, membership: project, user: author, role: 'author')
    create(:membership, membership: project, user: viewer, role: 'viewer')
  end

  def build_srg_component(name:, prefix:, decide: true, lock: true, version: 1, release: 1)
    component = Component.create!(project: project, name: name, prefix: prefix,
                                  title: "#{name} title", document_type: 'srg',
                                  based_on: core, version: version, release: release)
    if decide
      component.authored_srg_rules.each do |row|
        row.update!(status: 'Applicable', audit_comment: 'release spec setup')
        row.update!(locked: true, audit_comment: 'release spec setup') if lock
      end
    end
    component
  end

  it 'requires authentication' do
    component = build_srg_component(name: 'Release Auth Gate', prefix: 'RLAG-00')
    post "/components/#{component.id}/release", as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects a viewer with 403 and releases nothing' do
    component = build_srg_component(name: 'Release Viewer Gate', prefix: 'RLVG-00')
    sign_in viewer

    post "/components/#{component.id}/release", as: :json

    expect(response).to have_http_status(:forbidden)
    expect(component.reload.released).to be(false)
    expect(SecurityRequirementsGuide.exists?(srg_id: 'Release_Viewer_Gate')).to be(false)
  end

  context 'when signed in as an author' do
    before { sign_in author }

    it 'returns 422 with the undecided-requirements message while any row is Not Yet Determined' do
      component = build_srg_component(name: 'Release NYD Gate', prefix: 'RLNG-00', decide: false)

      post "/components/#{component.id}/release", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'message').join).to include('Not Yet Determined')
      expect(component.reload.released).to be(false)
      expect(SecurityRequirementsGuide.exists?(srg_id: 'Release_NYD_Gate')).to be(false)
    end

    it 'returns 422 for unlocked rows AND rolls the attachment back — no catalog row survives' do
      component = build_srg_component(name: 'Release Lock Gate', prefix: 'RLLG-00', lock: false)

      post "/components/#{component.id}/release", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'message').join)
        .to include('Cannot release a component that contains rules that are not yet locked')
      expect(component.reload.released).to be(false)
      expect(SecurityRequirementsGuide.exists?(srg_id: 'Release_Lock_Gate')).to be(false)
    end

    it 'returns 422 for a non-SRG component' do
      stig_component = create(:component, :skip_rules, project: project, name: 'Release Kind Gate',
                                                       prefix: 'RLKG-00', version: 1, release: 1)

      post "/components/#{stig_component.id}/release", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'message').join).to include('SRG component')
    end

    it 'returns 422 when the component is already released' do
      component = build_srg_component(name: 'Release Twice Gate', prefix: 'RLTG-00')
      post "/components/#{component.id}/release", as: :json
      expect(response).to have_http_status(:ok)

      post "/components/#{component.id}/release", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'message').join).to include('already released')
    end

    it 'rejects flipping released via component update for SRG kind — the release flow is the only path' do
      component = build_srg_component(name: 'Release Update Guard', prefix: 'RLUG-00')

      patch "/components/#{component.id}", params: { component: { released: true } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'message').join)
        .to include('SRG components release through the release flow')
      expect(component.reload.released).to be(false)
      expect(SecurityRequirementsGuide.exists?(srg_id: 'Release_Update_Guard')).to be(false)
    end

    it 'releases: catalog entry attached, component flagged, changelog returned — one success shape' do
      component = build_srg_component(name: 'Release Success Path', prefix: 'RLSP-00')

      post "/components/#{component.id}/release", as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig('toast', 'variant')).to eq('success')

      catalog = SecurityRequirementsGuide.find_by!(srg_id: 'Release_Success_Path')
      expect(body['catalog_srg']).to eq(
        'id' => catalog.id, 'srg_id' => 'Release_Success_Path', 'version' => 'V1R1',
        'name' => 'Release Success Path - Ver 1, Rel 1'
      )
      expect(body.dig('changelog', 'version')).to eq('V1R1')
      expect(body.dig('changelog', 'removals')).to eq([])
      expect(body.dig('changelog', 'text')).to include('No requirements were removed in this release.')

      expect(component.reload.released).to be(true)
      expect(catalog.srg_rules.count).to eq(2)
    end
  end
end
