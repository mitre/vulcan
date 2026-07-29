# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Component release endpoint contract', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:core) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-RELCON', version: 'V1R1')
  end
  let_it_be(:core_row) do
    create(:srg_rule, security_requirements_guide: core, version: 'SRG-OS-000851')
  end
  let_it_be(:project) { create(:project, name: 'Release Contract Project') }

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  def build_srg_component(name:, prefix:, decided: true)
    component = Component.create!(project: project, name: name, prefix: prefix,
                                  title: "#{name} title", document_type: 'srg',
                                  based_on: core, version: 1, release: 1)
    if decided
      component.authored_srg_rules.each do |row|
        row.update!(status: 'Applicable', audit_comment: 'contract setup')
        row.update!(locked: true, audit_comment: 'contract setup')
      end
    end
    component
  end

  describe 'POST /components/:id/release (JSON)' do
    it 'returns ComponentReleaseResponse on success' do
      component = build_srg_component(name: 'Contract Release Success', prefix: 'CRSC-00')

      post "/components/#{component.id}/release", headers: json_headers, as: :json
      body = validate_and_parse!

      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('catalog_srg', 'srg_id')).to eq('Contract_Release_Success')
      expect(body.dig('catalog_srg', 'version')).to eq('V1R1')
      expect(body.dig('changelog', 'removals')).to eq([])
      expect(body.dig('changelog', 'text')).to include('No requirements were removed')
    end

    it 'returns ToastResponse with the blocking reasons on 422' do
      component = build_srg_component(name: 'Contract Release Blocked', prefix: 'CRBL-00', decided: false)

      post "/components/#{component.id}/release", headers: json_headers, as: :json

      body = validate_and_parse!(expected_status: :unprocessable_content)
      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'message').join).to include('Not Yet Determined')
    end
  end
end
