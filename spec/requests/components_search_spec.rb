# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component search and rule picker' do
  include_context 'components request base setup'

  describe 'GET /components/:id/rules_picker.json' do
    it 'returns lightweight rule data with satisfaction IDs' do
      get "/components/#{component.id}/rules_picker.json"
      expect(response).to have_http_status(:ok)

      body = response.parsed_body
      expect(body).to have_key('rules')
      rule = body['rules'].first
      expect(rule).to have_key('id')
      expect(rule).to have_key('rule_id')
      expect(rule).to have_key('title')
      expect(rule).to have_key('satisfied_by')
      expect(rule).to have_key('satisfies')
      expect(rule).not_to have_key('fixtext')
      expect(rule).not_to have_key('vuln_discussion')
      expect(rule).not_to have_key('checks_attributes')
    end

    it 'requires authentication' do
      sign_out user
      get "/components/#{component.id}/rules_picker.json"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'conceals an unreleased component from a non-member (hidden project → 404)' do
      outsider = create(:user)
      sign_in outsider
      get "/components/#{component.id}/rules_picker.json"
      expect(response).to have_http_status(:not_found)
    end
  end

  # The picker backs move-to-rule / duplicate-target selection in triage
  # admin actions — it must serve authored requirements for srg-kind
  # components, not silently return an empty list.
  describe 'GET /components/:id/rules_picker.json for an SRG component' do
    let_it_be(:srg_component) do
      create(:component, :skip_rules, project: project, document_type: 'srg',
                                      prefix: 'PICK-00', name: 'Picker SRG')
    end
    let_it_be(:authored_requirement) do
      create(:srg_rule, :authored, component: srg_component, rule_id: '000001',
                                   title: 'Authored picker requirement')
    end

    it 'returns authored requirements in picker shape with Rule-only keys omitted' do
      get "/components/#{srg_component.id}/rules_picker.json"
      expect(response).to have_http_status(:ok)

      rows = response.parsed_body['rules']
      expect(rows.pluck('id')).to contain_exactly(authored_requirement.id)

      row = rows.first
      expect(row['rule_id']).to eq('000001')
      expect(row['title']).to eq('Authored picker requirement')
      expect(row['displayed_name']).to eq('PICK-00-000001')
      # Authored rows omit Rule-only keys entirely — never empty arrays.
      expect(row).not_to have_key('satisfies')
      expect(row).not_to have_key('satisfied_by')
    end
  end

  describe 'POST /components/:id/find' do
    let_it_be(:rule) { component.rules.first || create(:rule, component: component, title: 'Test LIKE injection rule') }
    let_it_be(:check_match_rule) do
      row = create(:rule, component: component, rule_id: '999901',
                          title: 'Rule found only through its check')
      Check.create!(base_rule: row, content: 'Verify the flotsam-marker audit configuration.')
      row
    end

    it 'sanitizes LIKE wildcards in search input' do
      post "/components/#{component.id}/find", params: { find: '%' }, as: :json
      expect(response).to have_http_status(:ok)
      results = response.parsed_body
      expect(results).to be_an(Array)
      expect(results.length).to be < component.rules.count
    end

    it 'returns the matching rule for a title search' do
      post "/components/#{component.id}/find", params: { find: rule.title.first(8) }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('id')).to include(rule.id)
    end

    it 'reaches a rule through its check content' do
      post "/components/#{component.id}/find", params: { find: 'flotsam-marker' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('id')).to eq([check_match_rule.id])
    end
  end

  # An SRG component stores requirements as authored SrgRules — the Rule STI
  # association is structurally empty for it, so an un-routed find silently
  # returns nothing. The searched columns all live on base_rules and both
  # child tables key on base_rule, so one field list serves both kinds.
  describe 'POST /components/:id/find on an SRG component' do
    let_it_be(:srg_component) do
      create(:component, :skip_rules, project: project, document_type: 'srg',
                                      prefix: 'FIND-00', name: 'Find SRG', title: 'Find SRG')
    end
    let_it_be(:title_match) do
      create(:srg_rule, :authored, component: srg_component, rule_id: '000001',
                                   title: 'Container escape prevention requirement')
    end
    let_it_be(:discussion_match) do
      row = create(:srg_rule, :authored, component: srg_component, rule_id: '000002',
                                         title: 'An unrelated requirement title')
      DisaRuleDescription.create!(base_rule: row, vuln_discussion: 'kernel hardening discussion text')
      row
    end
    let_it_be(:non_match) do
      create(:srg_rule, :authored, component: srg_component, rule_id: '000003',
                                   title: 'Nothing searchable here')
    end

    it 'returns authored requirements matching the search text in title' do
      post "/components/#{srg_component.id}/find", params: { find: 'container escape' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('rule_id')).to eq(%w[000001])
    end

    it 'reaches an authored requirement through its description child row' do
      post "/components/#{srg_component.id}/find", params: { find: 'kernel hardening' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck('rule_id')).to eq(%w[000002])
    end

    it 'serializes matches in the authored requirement shape, not the Rule shape' do
      post "/components/#{srg_component.id}/find", params: { find: 'container escape' }, as: :json
      row = response.parsed_body.first

      expect(row['srg_id']).to eq(title_match.version)
      expect(row).not_to have_key('satisfies')
      expect(row).not_to have_key('satisfied_by')
    end
  end

  # GET /search/components — the legacy global lookup by the srg_id a
  # component is based on, as compact [id, name] tuples. Access-scoped:
  # project or component membership, or a released component; admins all.
  describe 'GET /search/components (legacy component lookup)' do
    it 'finds components based on the queried SRG for a member' do
      get '/search/components', params: { q: component.based_on.srg_id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['components']).to include([component.id, component.name])
    end

    context 'as a non-member' do
      let(:outsider) { create(:user) }

      before do
        sign_out user
        sign_in outsider
      end

      it 'conceals components of projects the user is not a member of' do
        get '/search/components', params: { q: component.based_on.srg_id }

        expect(response.parsed_body['components']).not_to include([component.id, component.name])
      end

      it 'returns released components, and only those' do
        released = create(:component, project: create(:project), released: true)

        get '/search/components', params: { q: released.based_on.srg_id }

        tuples = response.parsed_body['components']
        expect(tuples).to include([released.id, released.name])
        # The member-only component is based on the same SRG; it must stay
        # hidden in the same response that serves the released match.
        expect(tuples).not_to include([component.id, component.name])
      end
    end
  end
end
