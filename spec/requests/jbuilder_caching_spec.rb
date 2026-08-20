# frozen_string_literal: true

require 'rails_helper'

##
# Jbuilder Caching Regression Tests
#
# REQUIREMENTS:
# - Verify collection caching is enabled (cached: true)
# - Verify cache invalidates when records update
# - Protect against regressions where caching is accidentally removed
#
RSpec.describe 'Jbuilder Caching' do
  let_it_be(:user) { create(:user) }

  before do
    Rails.application.reload_routes!
    sign_in user
    Rails.cache.clear # Start with empty cache
  end

  shared_examples 'consistent cached JSON' do |path|
    it 'returns consistent JSON with caching enabled' do
      get path
      expect(response).to have_http_status(:success)
      first_body = response.body

      get path
      expect(response).to have_http_status(:success)
      expect(response.body).to eq(first_body)
    end
  end

  describe 'Components index caching' do
    let!(:component) { create(:component, released: true) }

    it_behaves_like 'consistent cached JSON', '/components.json'
  end

  describe 'STIGs index caching' do
    let_it_be(:stig) { create(:stig) }

    it_behaves_like 'consistent cached JSON', '/stigs.json'
  end

  describe 'SRGs index caching' do
    let_it_be(:srg) { create(:security_requirements_guide) }

    it_behaves_like 'consistent cached JSON', '/srgs.json'
  end

  # ==========================================================================
  # Deterministic ordering of serialized rule collections.
  #
  # A serialized has_many with no ORDER BY returns rows in arbitrary Postgres
  # order, so two identical reads can differ (the original "consistent cached
  # JSON" flake). The contract is a deterministic TOTAL order: rules serialize
  # by their DISA `version` (the STIG-ID / SRG-ID — DISA's published document
  # order, zero-padded so lexical == canonical) with `:id` as the unique
  # tiebreaker. Rules are created OUT of version order below, so a green test
  # proves ordering, not insertion luck.
  # ==========================================================================
  describe 'STIG show serializes stig_rules in canonical (version) order' do
    let_it_be(:stig) { create(:stig, :skip_rules) }
    let_it_be(:mid)   { create(:stig_rule, stig: stig, version: 'RHEL-09-211020') }
    let_it_be(:first) { create(:stig_rule, stig: stig, version: 'RHEL-09-211010') }
    let_it_be(:last)  { create(:stig_rule, stig: stig, version: 'RHEL-09-211030') }

    it 'returns stig_rules ordered by version' do
      get "/stigs/#{stig.id}.json"
      expect(response).to have_http_status(:success)
      versions = response.parsed_body['stig_rules'].pluck('version')
      expect(versions).to eq(%w[RHEL-09-211010 RHEL-09-211020 RHEL-09-211030])
    end

    it 'cache invalidates when a rule updates' do
      get "/stigs/#{stig.id}.json"
      first_body = response.body

      first.update(title: 'Updated title')

      get "/stigs/#{stig.id}.json"
      expect(response.body).not_to eq(first_body)
      expect(response.body).to include('Updated title')
    end
  end

  describe 'SRG show serializes srg_rules in canonical (version) order' do
    let_it_be(:srg)   { create(:security_requirements_guide, :skip_rules) }
    let_it_be(:mid)   { create(:srg_rule, security_requirements_guide: srg, version: 'SRG-OS-000020-GPOS-00020') }
    let_it_be(:first) { create(:srg_rule, security_requirements_guide: srg, version: 'SRG-OS-000010-GPOS-00010') }
    let_it_be(:last)  { create(:srg_rule, security_requirements_guide: srg, version: 'SRG-OS-000030-GPOS-00030') }

    it 'returns srg_rules ordered by version' do
      get "/srgs/#{srg.id}.json"
      expect(response).to have_http_status(:success)
      versions = response.parsed_body['srg_rules'].pluck('version')
      expect(versions).to eq(%w[SRG-OS-000010-GPOS-00010 SRG-OS-000020-GPOS-00020 SRG-OS-000030-GPOS-00030])
    end
  end

  describe 'Component show serializes rules in canonical (version) order' do
    let_it_be(:ordering_project) { create(:project) }
    let_it_be(:component) { create(:component, :skip_rules, project: ordering_project) }
    let_it_be(:mid)   { create(:rule, component: component, version: 'ABCD-00-000020') }
    let_it_be(:first) { create(:rule, component: component, version: 'ABCD-00-000010') }
    let_it_be(:last)  { create(:rule, component: component, version: 'ABCD-00-000030') }

    let(:expected_versions) { %w[ABCD-00-000010 ABCD-00-000020 ABCD-00-000030] }

    context 'editor view (project member)' do
      let_it_be(:member) { create(:user) }
      let_it_be(:member_membership) do
        Membership.create!(user: member, membership: ordering_project, role: 'admin')
      end

      it 'returns rules ordered by version' do
        sign_in member
        get "/components/#{component.id}.json"
        expect(response).to have_http_status(:success)
        versions = response.parsed_body['rules'].pluck('version')
        expect(versions).to eq(expected_versions)
      end
    end

    context 'show view (non-member viewing released component)' do
      before do
        component.rules.update_all(locked: true) # release requires all rules locked
        component.update!(released: true)
      end

      it 'returns rules ordered by version' do
        # signed-in `user` is not a member of ordering_project -> :show view
        get "/components/#{component.id}.json"
        expect(response).to have_http_status(:success)
        versions = response.parsed_body['rules'].pluck('version')
        expect(versions).to eq(expected_versions)
      end
    end
  end
end
