# frozen_string_literal: true

require 'rails_helper'

# Dashboard endpoints: single-call SQL aggregates that power SPA dashboards
# without fetching all rules/reviews client-side. Component level: stats,
# workflow_state, triage_summary. Project level: stats (aggregate +
# per-component breakdown), triage_summary. Percentages are null (never a
# fabricated 0.0) when the denominator is zero.
RSpec.describe 'Dashboard stats' do
  let_it_be(:existing_admin) { create(:user, admin: true) } # -- side effect: prevents first-user-admin promotion
  let_it_be(:member) { create(:user) }
  let_it_be(:outsider) { create(:user) }
  let_it_be(:reviewer) { create(:user) }

  let_it_be(:project) { create(:project, name: 'Dashboard Project', visibility: :hidden) }
  let_it_be(:membership) { create(:membership, :viewer, user: member, membership: project) }

  # Component A: 5 rules (2 NYD, 1 AC locked, 1 IM under-review, 1 NA)
  # -> determined 3/5 (60.0%), locked 1/5 (20.0%), under_review 1.
  # A rule cannot be locked AND under review (model validation).
  let_it_be(:component) do
    create(:component, :skip_rules, project: project, prefix: 'DASH-01', name: 'Dashboard Component')
  end
  let_it_be(:dash_rules) do
    [
      create(:rule, component: component, status: 'Not Yet Determined', rule_severity: 'medium'),
      create(:rule, component: component, status: 'Not Yet Determined', rule_severity: 'medium'),
      create(:rule, component: component, status: 'Applicable - Configurable', rule_severity: 'high', locked: true),
      create(:rule, component: component, status: 'Applicable - Inherently Meets', rule_severity: 'medium',
                    review_requestor: reviewer),
      create(:rule, component: component, status: 'Not Applicable', rule_severity: 'low')
    ]
  end
  # Top-level comments: 2 rule-attached pending, 1 concur (awaiting
  # adjudication), 1 informational (terminal -> auto-adjudicated), and
  # 1 COMPONENT-LEVEL pending comment (commentable = component, no rule) —
  # component-level comments sit in the same triage queue and must count.
  # Plus 1 reply that must never count in triage aggregates.
  let_it_be(:comment_pending_one) { create(:review, :comment, rule: dash_rules[0], user: member) }
  let_it_be(:comment_pending_two) { create(:review, :comment, rule: dash_rules[1], user: member) }
  let_it_be(:comment_concur) { create(:review, :comment, :concur, rule: dash_rules[2], user: member) }
  let_it_be(:comment_informational) { create(:review, :comment, :informational, rule: dash_rules[3], user: member) }
  let_it_be(:component_level_comment) do
    create(:review, :component_comment, commentable: component, user: member)
  end
  let_it_be(:reply) do
    create(:review, :comment, rule: dash_rules[0], user: member,
                              responding_to_review_id: comment_pending_one.id, section: comment_pending_one.section)
  end

  # Component B: 1 NYD rule, no comments — exercises project aggregation
  # and the zero-comment triage summary.
  let_it_be(:component_b) do
    create(:component, :skip_rules, project: project, prefix: 'DASH-02', name: 'Dashboard Component B')
  end
  let_it_be(:rule_b) { create(:rule, component: component_b, status: 'Not Yet Determined', rule_severity: 'low') }

  before do
    Rails.application.reload_routes!
  end

  describe 'GET /api/components/:id/stats' do
    it 'requires authentication and viewer permission' do
      get "/api/components/#{component.id}/stats"
      expect(response).to have_http_status(:unauthorized)

      sign_in outsider
      get "/api/components/#{component.id}/stats"
      expect(response).to have_http_status(:not_found)
    end

    it 'returns rules by status, by severity, and completion/lock percentages' do
      sign_in member

      get "/api/components/#{component.id}/stats"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['rules_by_status']).to eq(
        'not_yet_determined' => 2, 'applicable_configurable' => 1,
        'applicable_inherently_meets' => 1, 'applicable_does_not_meet' => 0,
        'not_applicable' => 1
      )
      expect(body['rules_by_severity']).to eq('high' => 1, 'medium' => 3, 'low' => 1)
      expect(body['rule_count']).to eq(5)
      expect(body['completion_pct']).to eq(60.0)
      expect(body['lock_pct']).to eq(20.0)
    end

    it 'returns null percentages for a component with no rules (never a fabricated 0.0)' do
      empty = create(:component, :skip_rules, project: project, prefix: 'DASH-99', name: 'Empty Component')
      sign_in member

      get "/api/components/#{empty.id}/stats"

      body = response.parsed_body
      expect(body['rule_count']).to eq(0)
      expect(body['completion_pct']).to be_nil
      expect(body['lock_pct']).to be_nil
    end
  end

  describe 'GET /api/components/:id/workflow_state' do
    it 'returns readiness for authoring, locks, reviews, comments, triage, and export' do
      sign_in member

      get "/api/components/#{component.id}/workflow_state"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['authoring']).to eq('rules_total' => 5, 'rules_determined' => 3)
      expect(body['locks']).to eq('locked' => 1, 'total' => 5, 'all_locked' => false)
      expect(body['reviews']).to eq('under_review' => 1)
      expect(body['comment']).to eq(
        'phase' => 'open', 'accepting_new_comments' => true,
        'triaging_active' => true, 'frozen_for_writes' => false,
        'pending_comments' => 3
      )
      expect(body['triage']).to eq('pending' => 3, 'awaiting_adjudication' => 1)
      expect(body['export']).to eq('released' => false, 'releasable' => false)
    end

    it 'requires viewer permission' do
      sign_in outsider

      get "/api/components/#{component.id}/workflow_state"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/components/:id/triage_summary' do
    it 'counts top-level comments per triage status and computes adjudication pct' do
      sign_in member

      get "/api/components/#{component.id}/triage_summary"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['by_triage_status']).to eq(
        'pending' => 3, 'concur' => 1, 'concur_with_comment' => 0,
        'non_concur' => 0, 'duplicate' => 0, 'informational' => 1,
        'needs_clarification' => 0, 'withdrawn' => 0, 'addressed_by' => 0
      )
      expect(body['total']).to eq(5)
      expect(body['adjudicated']).to eq(1)
      expect(body['adjudication_pct']).to eq(20.0)
    end

    it 'returns null adjudication pct when there are no top-level comments' do
      sign_in member

      get "/api/components/#{component_b.id}/triage_summary"

      body = response.parsed_body
      expect(body['total']).to eq(0)
      expect(body['adjudicated']).to eq(0)
      expect(body['adjudication_pct']).to be_nil
    end
  end

  describe 'GET /api/projects/:id/stats' do
    it 'aggregates across components and includes a per-component breakdown' do
      sign_in member

      get "/api/projects/#{project.id}/stats"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig('aggregate', 'rule_count')).to eq(6)
      # The legacy flat aggregate is gone — typed sections are the only shape.
      expect(body['aggregate']).not_to have_key('rules_by_status')
      expect(body.dig('aggregate', 'rules_by_status_by_type', 'stig')).to include(
        'not_yet_determined' => 3, 'applicable_configurable' => 1
      )
      expect(body.dig('aggregate', 'rules_by_severity')).to eq('high' => 1, 'medium' => 3, 'low' => 2)
      expect(body.dig('aggregate', 'completion_pct')).to eq(50.0)

      rows = body['components']
      a = rows.find { |c| c['id'] == component.id }
      expect(a).to eq(
        'id' => component.id, 'name' => 'Dashboard Component', 'prefix' => 'DASH-01',
        'document_type' => 'stig',
        'rule_count' => 5, 'completion_pct' => 60.0, 'lock_pct' => 20.0
      )
      b = rows.find { |c| c['id'] == component_b.id }
      expect(b['rule_count']).to eq(1)
      expect(b['completion_pct']).to eq(0.0)
    end

    it 'requires viewer permission on the project' do
      sign_in outsider

      get "/api/projects/#{project.id}/stats"

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for an unknown project' do
      sign_in member

      get '/api/projects/0/stats'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/projects/:id/triage_summary' do
    it 'aggregates triage metrics across all project components' do
      sign_in member

      get "/api/projects/#{project.id}/triage_summary"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['by_triage_status']).to include('pending' => 3, 'concur' => 1, 'informational' => 1)
      expect(body['total']).to eq(5)
      expect(body['adjudicated']).to eq(1)
      expect(body['adjudication_pct']).to eq(20.0)
    end

    it 'requires viewer permission on the project' do
      sign_in outsider

      get "/api/projects/#{project.id}/triage_summary"

      expect(response).to have_http_status(:not_found)
    end
  end
end
