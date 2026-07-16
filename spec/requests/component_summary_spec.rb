# frozen_string_literal: true

require 'rails_helper'

# GET /api/components/:id/summary — lightweight component header for SPA
# triage/settings routes: identity, counts, srg info, effective_permissions,
# and the serialized comment-phase state machine. Never ships the heavy
# rules/reviews/histories arrays, so clients stop fetching the full :editor
# blob just to read phase state. Phase booleans come from the model methods
# (single source of truth) and are pinned here for every reachable
# phase/closed_reason combination.
RSpec.describe 'Component summary' do
  let_it_be(:existing_admin) { create(:user, admin: true) } # -- side effect: prevents first-user-admin promotion
  let_it_be(:member) { create(:user) }
  let_it_be(:outsider) { create(:user) }

  let_it_be(:project) { create(:project, name: 'Summary Project', visibility: :hidden) }
  let_it_be(:membership) { create(:membership, :viewer, user: member, membership: project) }
  let_it_be(:component) do
    create(:component, :skip_rules, project: project,
                                    prefix: 'SUMM-01', name: 'Summary Component', title: 'Summary Component Title',
                                    version: 2, release: 1,
                                    comment_phase: 'open', comment_period_ends_at: 36.hours.from_now)
  end
  let_it_be(:rules) do
    [
      create(:rule, component: component, rule_severity: 'high'),
      create(:rule, component: component, rule_severity: 'medium')
    ]
  end

  before do
    Rails.application.reload_routes!
  end

  describe 'GET /api/components/:id/summary' do
    it 'requires authentication' do
      get "/api/components/#{component.id}/summary"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['type']).to eq('/api/docs/errors#not_authenticated')
    end

    it 'conceals unreleased components from non-members (hidden project → 404)' do
      sign_in outsider

      get "/api/components/#{component.id}/summary"

      expect(response).to have_http_status(:not_found)
    end

    it 'returns identity and srg header fields for a member' do
      sign_in member

      get "/api/components/#{component.id}/summary"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['id']).to eq(component.id)
      expect(body['name']).to eq('Summary Component')
      expect(body['prefix']).to eq('SUMM-01')
      expect(body['title']).to eq('Summary Component Title')
      expect(body['version']).to eq(2)
      expect(body['release']).to eq(1)
      expect(body['released']).to be(false)
      expect(body['project_id']).to eq(project.id)
      expect(body['security_requirements_guide_id']).to eq(component.security_requirements_guide_id)
      expect(body['based_on_title']).to eq(component.based_on.title)
      expect(body['based_on_version']).to eq(component.based_on.version)
    end

    it 'returns counts and permissions — without the heavy rules/reviews/histories arrays' do
      sign_in member

      get "/api/components/#{component.id}/summary"

      body = response.parsed_body
      expect(body['rules_count']).to eq(2)
      expect(body['severity_counts']).to eq('high' => 1, 'medium' => 1, 'low' => 0)
      expect(body['effective_permissions']).to eq('viewer')
      expect(body).not_to have_key('rules')
      expect(body).not_to have_key('reviews')
      expect(body).not_to have_key('histories')
    end

    it 'serializes the open phase: accepting, triaging, not frozen, with days remaining' do
      sign_in member

      get "/api/components/#{component.id}/summary"

      body = response.parsed_body
      expect(body['comment_phase']).to eq('open')
      expect(body['accepting_new_comments']).to be(true)
      expect(body['triaging_active']).to be(true)
      expect(body['frozen_for_writes']).to be(false)
      expect(body['comment_period_days_remaining']).to eq(2)
    end

    # Exhaustive phase/closed_reason matrix — these booleans are server
    # write-guards; a client trusting a wrong value predicts the wrong
    # rejection behavior.
    {
      ['open', nil] => { 'accepting_new_comments' => true, 'triaging_active' => true,
                         'frozen_for_writes' => false },
      ['closed', nil] => { 'accepting_new_comments' => false, 'triaging_active' => false,
                           'frozen_for_writes' => false },
      %w[closed adjudicating] => { 'accepting_new_comments' => false, 'triaging_active' => true,
                                   'frozen_for_writes' => false },
      %w[closed finalized] => { 'accepting_new_comments' => false, 'triaging_active' => false,
                                'frozen_for_writes' => true }
    }.each do |(phase, reason), expected|
      it "serializes phase=#{phase} closed_reason=#{reason.inspect} as #{expected.inspect}" do
        phased = create(:component, :skip_rules, project: project,
                                                 comment_phase: phase, closed_reason: reason)
        sign_in member

        get "/api/components/#{phased.id}/summary"

        body = response.parsed_body
        expect(body.slice(*expected.keys)).to eq(expected)
        expect(body['comment_period_days_remaining']).to be_nil unless phase == 'open'
      end
    end

    it 'allows any authenticated user to read a released component summary' do
      released = create(:component, :skip_rules, :released_component, project: project, prefix: 'RELS-01')
      sign_in outsider

      get "/api/components/#{released.id}/summary"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['released']).to be(true)
      expect(body['effective_permissions']).to be_nil
    end

    it 'returns 404 for an unknown component' do
      sign_in member

      get '/api/components/0/summary'

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['type']).to eq('/api/docs/errors#not_found')
    end
  end
end
