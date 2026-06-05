# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Components' do
  include_context 'components request base setup'

  # REQUIREMENT: Delete component must clean up all dependent records
  # without N+1 callbacks. Bulk delete for performance.
  describe 'DELETE /components/:id' do
    it 'destroys component and all dependent records' do
      # Use a fresh component so we don't destroy the shared one
      doomed = create(:component, project: project)
      rule_ids = doomed.rules.pluck(:id)

      delete "/components/#{doomed.id}",
             headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success)
      expect(Component.find_by(id: doomed.id)).to be_nil
      expect(Rule.unscoped.where(id: rule_ids).count).to eq(0)
    end
  end

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
  end

  # blueprint_render_options plucked ALL review IDs for a
  # component (3000+) and passed them to Reaction.summary, generating two
  # massive GROUP BY queries on every editor refresh. Scope to ≤100 review IDs.
  describe 'GET /components/:id (reaction scoping)' do
    it 'show does not load reactions for non-displayed reviews' do
      rule = component.rules.first
      # Seed >100 reviews to trigger the over-fetch the card targets.
      Review.transaction do
        110.times do |i|
          Review.insert!({
                           rule_id: rule.id,
                           commentable_type: 'BaseRule', commentable_id: rule.id,
                           user_id: user.id, action: 'comment',
                           comment: "scoping-test #{i}",
                           created_at: Time.current, updated_at: Time.current
                         })
        end
      end

      captured = nil
      allow(Reaction).to receive(:summary).and_wrap_original do |orig, ids, *rest|
        captured = ids
        orig.call(ids, *rest)
      end

      get "/components/#{component.id}", headers: { 'Accept' => application_json }
      expect(response).to have_http_status(:ok)

      expect(captured).not_to be_nil, 'Reaction.summary was not called'
      expect(captured.size).to be <= 100,
                               "expected ≤ 100 review ids passed to Reaction.summary; got #{captured.size}"
    end
  end

  describe 'POST /components/:id/find' do
    let_it_be(:rule) { component.rules.first || create(:rule, component: component, title: 'Test LIKE injection rule') }

    it 'sanitizes LIKE wildcards in search input' do
      post "/components/#{component.id}/find", params: { find: '%' }, as: :json
      expect(response).to have_http_status(:ok)
      results = response.parsed_body
      expect(results).to be_an(Array)
      expect(results.length).to be < component.rules.count
    end

    it 'returns matching rules for normal search' do
      post "/components/#{component.id}/find", params: { find: rule.title.first(8) }, as: :json
      expect(response).to have_http_status(:ok)
    end
  end
end
