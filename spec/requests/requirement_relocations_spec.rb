# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT (relocation marker API): authors of an SRG component mark a
# requirement for relocation (create a pending record), un-mark it
# (destroy the pending record), and read the per-family backlog. Executed
# records are untouchable through the API. Backlog rows are scoped to
# projects the caller can see.
RSpec.describe 'Requirement relocations' do
  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:author) { create(:user) }
  let_it_be(:viewer) { create(:user) }
  let_it_be(:core_srg) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-RELOCAPI', version: 'V1R1')
  end
  let_it_be(:project) { create(:project) }
  let_it_be(:srg_component) do
    create(:component, :skip_rules, project: project, document_type: 'srg',
                                    based_on: core_srg, prefix: 'RAPI-00')
  end
  let_it_be(:author_membership) do
    Membership.create!(user: author, membership: project, role: 'author')
  end
  let_it_be(:viewer_membership) do
    Membership.create!(user: viewer, membership: project, role: 'viewer')
  end

  before do
    Rails.application.reload_routes!
  end

  def authored_row(rule_id)
    create(:srg_rule, :authored, component: srg_component, rule_id: rule_id)
  end

  describe 'POST /rules/:rule_id/relocations (mark)' do
    it 'creates a pending marker for an author' do
      source = authored_row('910001')
      sign_in author

      post "/rules/#{source.id}/relocations",
           params: { requirement_relocation: { target_technology_token: 'CTR' } }

      expect(response).to have_http_status(:ok)
      record = RequirementRelocation.find_by!(source_rule_id: source.id)
      expect(record.target_technology_token).to eq('CTR')
      expect(record.requested_by_id).to eq(author.id)
      expect(record.executed_at).to be_nil
    end

    it 'rejects a duplicate pending marker with a 422 toast' do
      source = authored_row('910002')
      RequirementRelocation.create!(source_rule: source, target_technology_token: 'CTR')
      sign_in author

      post "/rules/#{source.id}/relocations",
           params: { requirement_relocation: { target_technology_token: 'GPOS' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'message').join).to match(/pending/i)
    end

    it 'forbids a viewer from marking' do
      source = authored_row('910003')
      sign_in viewer

      post "/rules/#{source.id}/relocations",
           params: { requirement_relocation: { target_technology_token: 'CTR' } }

      expect(response).not_to have_http_status(:ok)
      expect(RequirementRelocation.where(source_rule_id: source.id).count).to eq(0)
    end
  end

  describe 'DELETE /requirement_relocations/:id (un-mark)' do
    it 'destroys a pending marker for an author' do
      source = authored_row('910004')
      record = RequirementRelocation.create!(source_rule: source, target_technology_token: 'CTR')
      sign_in author

      delete "/requirement_relocations/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(RequirementRelocation.exists?(record.id)).to be false
    end

    it 'answers 404 for an executed record — immutable through the API' do
      source = authored_row('910005')
      executed = RequirementRelocation.create!(source_rule: source, target_technology_token: 'CTR',
                                               executed_at: 1.day.ago)
      sign_in author

      delete "/requirement_relocations/#{executed.id}"

      expect(response).to have_http_status(:not_found)
      expect(RequirementRelocation.exists?(executed.id)).to be true
    end
  end

  describe 'GET /requirement_relocations (per-family backlog)' do
    it 'lists pending markers for the token with source identity' do
      source = authored_row('910006')
      RequirementRelocation.create!(source_rule: source, target_technology_token: 'CTR',
                                    requested_by: author)
      other = authored_row('910007')
      RequirementRelocation.create!(source_rule: other, target_technology_token: 'GPOS')
      executed_source = authored_row('910008')
      RequirementRelocation.create!(source_rule: executed_source, target_technology_token: 'CTR',
                                    executed_at: 1.day.ago)
      sign_in author

      get '/requirement_relocations', params: { target_technology_token: 'CTR' }

      expect(response).to have_http_status(:ok)
      rows = response.parsed_body
      expect(rows.size).to eq(1)
      expect(rows.first['target_technology_token']).to eq('CTR')
      expect(rows.first['source_displayed_name']).to eq('RAPI-00-910006')
      expect(rows.first['component_id']).to eq(srg_component.id)
      expect(rows.first['requested_by_name']).to eq(author.name)
    end

    it 'excludes markers whose project the caller cannot see' do
      hidden_project = create(:project)
      hidden_component = create(:component, :skip_rules, project: hidden_project,
                                                         document_type: 'srg', based_on: core_srg,
                                                         prefix: 'RHID-00')
      hidden_source = create(:srg_rule, :authored, component: hidden_component, rule_id: '910009')
      RequirementRelocation.create!(source_rule: hidden_source, target_technology_token: 'CTR')
      sign_in author

      get '/requirement_relocations', params: { target_technology_token: 'CTR' }

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.pluck('id')
      expect(RequirementRelocation.find_by(source_rule_id: hidden_source.id).id).not_to be_in(ids)
    end
  end
end
