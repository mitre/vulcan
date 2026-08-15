# frozen_string_literal: true

require 'rails_helper'

# GET /api/components/latest serves the highest-versioned RELEASED component
# per prefix for dropdown population. A component is a STIG in
# progress — released ones are instance-wide reference data for any
# authenticated user (same visibility as the components list page).
# Ranking is numeric on the integer version/release columns.
RSpec.describe 'Api::Components' do
  let_it_be(:existing_admin) { create(:user, admin: true) } # -- side effect: prevents first-user-admin promotion
  let_it_be(:user) { create(:user) }

  let_it_be(:rhel_v1r3) do
    create(:component, :skip_rules, :released_component,
           prefix: 'RHEL-09', name: 'RHEL 9 Hardened Baseline', title: 'Red Hat Enterprise Linux 9',
           version: 1, release: 3)
  end
  let_it_be(:rhel_v2r1) do
    create(:component, :skip_rules, :released_component,
           prefix: 'RHEL-09', name: 'RHEL 9 Hardened Baseline', title: 'Red Hat Enterprise Linux 9',
           version: 2, release: 1)
  end
  let_it_be(:photon_v1r1) do
    create(:component, :skip_rules, :released_component,
           prefix: 'PHTN-50', name: 'Photon OS 5 Baseline', title: 'VMware Photon OS 5',
           version: 1, release: 1)
  end
  # Unreleased draft with a HIGHER version than the released RHEL-09 records —
  # must never appear, and must not shadow the released latest.
  let_it_be(:rhel_draft_v9) do
    create(:component, :skip_rules,
           prefix: 'RHEL-09', name: 'RHEL 9 Draft', title: 'Red Hat Enterprise Linux 9',
           version: 9, release: 9)
  end

  before do
    Rails.application.reload_routes!
    sign_in user
  end

  describe 'GET /api/components/latest' do
    it 'returns one released component per prefix with the numerically highest version/release' do
      get '/api/components/latest'

      expect(response).to have_http_status(:ok)
      rows = response.parsed_body['rows']
      expect(rows.size).to eq(2)
      rhel = rows.find { |r| r['prefix'] == 'RHEL-09' }
      expect(rhel['id']).to eq(rhel_v2r1.id)
      expect(rhel['version']).to eq(2)
      expect(rhel['release']).to eq(1)
      expect(rows.pluck('prefix')).to contain_exactly('RHEL-09', 'PHTN-50')
    end

    it 'never lists unreleased components, even at higher versions' do
      get '/api/components/latest'

      ids = response.parsed_body['rows'].pluck('id')
      expect(ids).not_to include(rhel_draft_v9.id)
    end

    it 'ranks nil versions below numbered ones (NULLS LAST, not Postgres default NULLS FIRST)' do
      nil_version = create(:component, :skip_rules, :released_component,
                           prefix: 'PHTN-50', name: 'Photon OS 5 Unversioned',
                           version: nil, release: nil)

      get '/api/components/latest'

      photon = response.parsed_body['rows'].find { |r| r['prefix'] == 'PHTN-50' }
      expect(photon['id']).to eq(photon_v1r1.id)
      expect(photon['id']).not_to eq(nil_version.id)
    end

    it 'returns exactly id, prefix, name, title, version, release per row' do
      get '/api/components/latest'

      row = response.parsed_body['rows'].find { |r| r['prefix'] == 'PHTN-50' }
      expect(row).to eq(
        'id' => photon_v1r1.id,
        'prefix' => 'PHTN-50',
        'name' => 'Photon OS 5 Baseline',
        'title' => 'VMware Photon OS 5',
        'version' => 1,
        'release' => 1
      )
    end

    it 'filters components by substring, case-insensitive (?q=photon)' do
      get '/api/components/latest', params: { q: 'photon' }

      rows = response.parsed_body['rows']
      expect(rows.pluck('prefix')).to eq(['PHTN-50'])
    end

    it 'matches against prefix as well as name (?q=RHEL-09)' do
      get '/api/components/latest', params: { q: 'RHEL-09' }

      rows = response.parsed_body['rows']
      expect(rows.pluck('prefix')).to eq(['RHEL-09'])
      expect(rows.first['id']).to eq(rhel_v2r1.id)
    end

    it 'returns 401 for unauthenticated requests (components are not public)' do
      sign_out user

      get '/api/components/latest'

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['type']).to eq('/docs/api/errors#not_authenticated')
    end
  end
end
