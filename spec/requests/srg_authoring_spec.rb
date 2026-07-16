# frozen_string_literal: true

require 'rails_helper'

# Backend scoping for SRG-kind components: every comment/triage/lock/
# release query must reach authored SrgRules through Component#requirements
# or a base_rules-scoped subquery. The Rule STI association structurally
# excludes them — without that, the triage table renders empty, dashboard
# aggregates omit SRG comments, lock-all locks nothing, and an SRG
# component can never be released.
RSpec.describe 'SRG authoring backend' do
  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg_component) do
    create(:component, :skip_rules, project: project, document_type: 'srg', prefix: 'SRGX-00',
                                    name: 'Authored SRG', title: 'Authored SRG')
  end
  let_it_be(:membership) { Membership.create!(user: admin, membership: project, role: 'admin') }
  let_it_be(:authored_a) { create(:srg_rule, :authored, component: srg_component, rule_id: '000001') }
  let_it_be(:authored_b) { create(:srg_rule, :authored, component: srg_component, rule_id: '000002') }
  let_it_be(:srg_comment) do
    create(:review, :comment, user: admin, rule: nil, commentable: authored_a,
                              comment: 'Feedback on an authored requirement', section: 'fixtext')
  end

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  describe 'GET /components/:id/comments — triage table' do
    it 'lists comments on authored SrgRules with the component-prefixed rule name' do
      get "/components/#{srg_component.id}/comments", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['pagination']['total']).to eq(1)
      row = body['rows'].first
      expect(row['id']).to eq(srg_comment.id)
      expect(row['rule_displayed_name']).to eq('SRGX-00-000001')
    end
  end

  describe 'Review.for_components — dashboard aggregates' do
    it 'includes comments on authored SrgRules' do
      expect(Review.for_components([srg_component.id]).ids).to include(srg_comment.id)
    end
  end

  describe 'POST /components/:id/lock — lock-all' do
    it 'locks decided authored SrgRules; undecided (NYD) rows are skipped with a warning' do
      component = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                  prefix: 'SRGL-00', name: 'Lockable SRG', title: 'Lockable SRG')
      decided_a = create(:srg_rule, :authored, component: component, rule_id: '000001',
                                               status: 'Applicable')
      decided_b = create(:srg_rule, :authored, component: component, rule_id: '000002',
                                               status: 'Not Applicable')
      undecided = create(:srg_rule, :authored, component: component, rule_id: '000003')

      post "/components/#{component.id}/lock",
           params: { review: { action: 'lock_control', comment: 'Locking for release' } }

      expect(response).to have_http_status(:ok)
      expect(decided_a.reload.locked).to be(true)
      expect(decided_b.reload.locked).to be(true)
      expect(undecided.reload.locked).to be(false)
      expect(response.parsed_body['toast']['message'].join("\n")).to include('SRGL-00-000003')
    end
  end

  describe 'GET /components/:id/comments with include_rule_content' do
    it 'serializes an SrgRule comment row with rule content and an empty satisfied_by' do
      get "/components/#{srg_component.id}/comments",
          params: { include_rule_content: 'true' }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      row = response.parsed_body['rows'].find { |r| r['id'] == srg_comment.id }
      expect(row['rule_content']['title']).to eq(authored_a.title)
      expect(row['rule_content']['satisfied_by']).to eq([])
    end
  end

  describe 'POST /rule_satisfactions — structurally absent for SRG' do
    it '404s a satisfaction call targeting an authored SrgRule' do
      post '/rule_satisfactions',
           params: { rule_id: authored_a.id, satisfied_by_rule_id: authored_b.id }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /components/:id.json — editor serves authored SrgRules' do
    it 'renders authored rows through the dedicated blueprint — no Rule-only surfaces' do
      get "/components/#{srg_component.id}.json"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['document_type']).to eq('srg')
      expect(body['status_counts'].keys)
        .to contain_exactly('not_yet_determined', 'applicable', 'not_applicable')

      rules = body['rules']
      expect(rules.pluck('rule_id')).to contain_exactly('000001', '000002')
      row = rules.find { |r| r['rule_id'] == '000001' }
      expect(row).to include('status', 'locked', 'comment_summary', 'fixtext', 'locked_fields')
      expect(row['comment_summary']).to eq('open' => 1, 'total' => 1)
      expect(row.keys).not_to include('satisfies', 'satisfied_by', 'srg_rule_attributes',
                                      'additional_answers_attributes', 'inspec_control_body')
    end
  end

  describe 'type-aware buckets' do
    it 'reports the three SRG buckets from live authored rows only' do
      component = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                  prefix: 'SRGC-00', name: 'Bucket SRG', title: 'Bucket SRG')
      create(:srg_rule, :authored, component: component, rule_id: '000001',
                                   status: 'Applicable', locked: true)
      create(:srg_rule, :authored, component: component, rule_id: '000002')
      tombstone = create(:srg_rule, :authored, component: component, rule_id: '000003',
                                               status: 'Applicable')
      tombstone.update_column(:deleted_at, Time.current)

      expect(component.status_counts).to eq(
        not_yet_determined: 1, applicable: 1, not_applicable: 0
      )

      stats = component.dashboard_stats
      expect(stats[:document_type]).to eq('srg')
      expect(stats[:rules_by_status]).to eq(not_yet_determined: 1, applicable: 1, not_applicable: 0)
      expect(stats[:rule_count]).to eq(2)
      expect(stats[:lock_pct]).to eq(50.0)
      expect(component.severity_counts).to eq(high: 0, medium: 2, low: 0)
    end
  end

  describe 'project aggregates' do
    let_it_be(:mixed_project) { create(:project, name: 'Mixed Types') }
    let_it_be(:stig_component) do
      create(:component, :skip_rules, project: mixed_project, prefix: 'STGM-00',
                                      name: 'Mixed STIG', title: 'Mixed STIG')
    end
    let_it_be(:stig_rules) do
      [create(:rule, component: stig_component, rule_id: '000001',
                     status: 'Applicable - Configurable'),
       create(:rule, component: stig_component, rule_id: '000002')]
    end
    let_it_be(:mixed_srg_component) do
      create(:component, :skip_rules, project: mixed_project, document_type: 'srg',
                                      prefix: 'SRGM-00', name: 'Mixed SRG', title: 'Mixed SRG')
    end
    let_it_be(:mixed_authored) do
      [create(:srg_rule, :authored, component: mixed_srg_component, rule_id: '000001',
                                    status: 'Applicable', locked: true),
       create(:srg_rule, :authored, component: mixed_srg_component, rule_id: '000002',
                                    status: 'Not Applicable')]
    end

    it 'details reports per-document-type sections with type-agnostic numbers top-level' do
      details = mixed_project.details

      expect(details[:stig]).to eq(
        ac: 1, aim: 0, adnm: 0, na: 0, nyd: 1, total: 2
      )
      expect(details[:srg]).to eq(
        applicable: 1, na: 1, nyd: 0, total: 2
      )
      # Type-agnostic numbers stay top-level; total spans both kinds.
      expect(details[:total]).to eq(4)
      expect(details[:lck]).to eq(1)
      # The legacy flat mirrors are REMOVED — typed sections only.
      expect(details).not_to have_key(:ac)
      expect(details).not_to have_key(:nyd)
    end

    it 'dashboard aggregates count every kind without collapsing buckets' do
      stats = mixed_project.dashboard_stats

      expect(stats[:aggregate][:rule_count]).to eq(4)
      # 3 of 4 requirements decided (only the stig NYD remains).
      expect(stats[:aggregate][:completion_pct]).to eq(75.0)
      expect(stats[:aggregate][:rules_by_status_by_type]).to eq(
        stig: { not_yet_determined: 1, applicable_configurable: 1,
                applicable_inherently_meets: 0, applicable_does_not_meet: 0,
                not_applicable: 0 },
        srg: { not_yet_determined: 0, applicable: 1, not_applicable: 1 }
      )
      # The legacy flat aggregate is REMOVED — typed sections only.
      expect(stats[:aggregate]).not_to have_key(:rules_by_status)

      srg_row = stats[:components].find { |c| c[:prefix] == 'SRGM-00' }
      expect(srg_row[:document_type]).to eq('srg')
      expect(srg_row[:rule_count]).to eq(2)
      expect(srg_row[:completion_pct]).to eq(100.0)
      expect(srg_row[:lock_pct]).to eq(50.0)
    end
  end

  describe 'project-level comment surfaces' do
    it 'Project#paginated_comments includes comments on authored SrgRules' do
      result = project.paginated_comments

      expect(result[:rows].pluck('id')).to include(srg_comment.id)
    end

    it 'GET /users/:id/comments lists a user\'s comments on authored SrgRules' do
      get "/users/#{admin.id}/comments", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['rows'].pluck('id')).to include(srg_comment.id)
    end
  end

  describe 'editor reaction summaries' do
    it 'includes reactions on authored-requirement comments' do
      Reaction.create!(review: srg_comment, user: admin, kind: 'up')

      get "/components/#{srg_component.id}.json"

      row = response.parsed_body['rules'].find { |r| r['rule_id'] == '000001' }
      review = row['reviews'].find { |r| r['id'] == srg_comment.id }
      expect(review['reactions']).to eq('up' => 1, 'down' => 0, 'mine' => 'up')
    ensure
      Reaction.where(review_id: srg_comment.id).destroy_all
    end
  end

  describe '#workflow_state' do
    it 'kind-routes lock and under-review counts to authored SrgRules' do
      component = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                  prefix: 'SRGW-00', name: 'Workflow SRG', title: 'Workflow SRG')
      create(:srg_rule, :authored, component: component, rule_id: '000001',
                                   status: 'Applicable', locked: true)
      create(:srg_rule, :authored, component: component, rule_id: '000002',
                                   review_requestor_id: admin.id)

      state = component.workflow_state
      expect(state[:document_type]).to eq('srg')
      expect(state[:locks]).to eq(locked: 1, total: 2, all_locked: false)
      expect(state[:reviews]).to eq(under_review: 1)
      expect(state[:authoring]).to eq(rules_total: 2, rules_determined: 1)
    end
  end

  describe 'rules controller serves authored requirements' do
    it 'GET /components/:id/rules returns the authored rows without Rule-only surfaces' do
      get "/components/#{srg_component.id}/rules", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      rows = response.parsed_body
      expect(rows.pluck('rule_id')).to contain_exactly('000001', '000002')
      expect(rows.first).to include('status', 'locked', 'comment_summary')
      expect(rows.first.keys).not_to include('satisfies', 'srg_rule_attributes')
    end

    it 'GET /rules/:id returns an individual authored requirement' do
      get "/rules/#{authored_a.id}", headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['id']).to eq(authored_a.id)
      expect(body['rule_id']).to eq('000001')
      expect(body.keys).not_to include('satisfies', 'srg_rule_attributes')
    end

    it 'PUT /rules/:id updates shared fields on an authored requirement' do
      put "/rules/#{authored_b.id}",
          params: { rule: { title: 'Updated via API', status: 'Not Applicable',
                            status_justification: 'Handled elsewhere' } }

      expect(response).to have_http_status(:ok)
      expect(authored_b.reload.title).to eq('Updated via API')
      expect(authored_b.status).to eq('Not Applicable')
    end

    it 'rejects a STIG-only status through the update path' do
      put "/rules/#{authored_b.id}",
          params: { rule: { status: 'Applicable - Configurable' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(authored_b.reload.status).not_to eq('Applicable - Configurable')
    end
  end

  describe 'component creation with a document_type' do
    it 'persists the chosen profile and never imports Rules onto an srg-kind component' do
      post "/projects/#{project.id}/components",
           params: { component: { name: 'API-created SRG', prefix: 'APIS-00',
                                  title: 'API-created SRG', version: 1, release: 1,
                                  security_requirements_guide_id: srg_component.security_requirements_guide_id,
                                  document_type: 'srg' } }

      created = Component.find_by(name: 'API-created SRG')
      expect(created).to be_present
      expect(created.document_type).to eq('srg')
      expect(created.rules.count).to eq(0)
      created.destroy!
    end
  end

  describe 'STIG-only surfaces are gated on srg-kind components' do
    it 'rejects manual Rule creation on an srg-kind component' do
      post "/components/#{srg_component.id}/rules",
           params: { rule: { rule_id: '999901' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(srg_component.rules.count).to eq(0)
    end

    it '404s the related-rules search for an authored requirement' do
      get "/rules/#{authored_a.id}/search/related_rules"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'section locks on authored requirements' do
    it 'locks a section and returns the authored requirement shape' do
      patch "/rules/#{authored_a.id}/section_locks",
            params: { section: 'Fix', locked: true }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['rule']['locked_fields']).to eq('Fix' => true)
      expect(body['rule'].keys).not_to include('satisfies', 'srg_rule_attributes')
      expect(authored_a.reload.locked_fields).to eq('Fix' => true)
    ensure
      authored_a.update_column(:locked_fields, {})
    end

    it 'bulk-locks sections and returns the authored requirement shape' do
      patch "/rules/#{authored_b.id}/bulk_section_locks",
            params: { sections: %w[Fix Check], locked: true }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['rule']['locked_fields']).to eq('Fix' => true, 'Check' => true)
      expect(body['rule'].keys).not_to include('satisfies')
      expect(authored_b.reload.locked_fields).to eq('Fix' => true, 'Check' => true)
    ensure
      authored_b.update_column(:locked_fields, {})
    end
  end

  describe 'release gate' do
    it 'accepts release once every live authored requirement is locked' do
      component = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                  prefix: 'SRGR-00', name: 'Releasable SRG', title: 'Releasable SRG')
      create(:srg_rule, :authored, component: component, rule_id: '000001',
                                   status: 'Applicable', locked: true)

      component.released = true
      expect(component).to be_valid
    end

    it 'rejects release while an authored requirement is unlocked' do
      component = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                  prefix: 'SRGU-00', name: 'Unreleasable SRG', title: 'Unreleasable SRG')
      create(:srg_rule, :authored, component: component, rule_id: '000001', status: 'Applicable')

      component.released = true
      expect(component).not_to be_valid
      expect(component.errors[:base])
        .to include('Cannot release a component that contains rules that are not yet locked')
    end
  end
end
