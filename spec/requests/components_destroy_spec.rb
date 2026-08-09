# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component destruction' do
  include QueryCountHelpers

  include_context 'components request base setup'

  # Destroy must be BULK for both document kinds: the query count cannot
  # scale with the requirement count. The end-state assertions alone cannot
  # see the difference — the per-row cascade deletes everything too, just
  # one row at a time — so the invariance is the only honest pin.
  # The first authenticated request in an example pays one-time session
  # bookkeeping queries — warm it so both measured destroys are steady-state.
  def warm_session
    get "/components/#{component.id}/related", headers: { 'Accept' => application_json }
    expect(response).to have_http_status(:success)
  end

  def destroy_query_count(component)
    report = count_queries do
      delete "/components/#{component.id}", headers: { 'Accept' => application_json }
    end
    expect(response).to have_http_status(:success)
    report.total
  end

  def build_srg_component(prefix, rows:)
    component = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                prefix: prefix, name: "Destroy #{prefix}",
                                                title: "Destroy #{prefix}")
    rows.times do |i|
      row = create(:srg_rule, :authored, component: component, rule_id: format('%06d', i + 1),
                                         title: "Requirement #{i + 1}")
      Check.create!(base_rule: row, content: "check #{i}")
      DisaRuleDescription.create!(base_rule: row, vuln_discussion: "discussion #{i}")
      Reference.create!(base_rule_id: row.id, title: "reference #{i}")
    end
    component
  end

  describe 'DELETE /components/:id' do
    it 'destroys component and all dependent records, leaving no orphans' do
      doomed = create(:component, project: project)
      rule_ids = doomed.rules.pluck(:id)
      # references has no database foreign key — only an explicit cleanup
      # keeps these rows from being orphaned by the bulk path.
      Reference.create!(base_rule_id: rule_ids.first, title: 'Orphan probe reference')

      delete "/components/#{doomed.id}",
             headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success)
      expect(Component.find_by(id: doomed.id)).to be_nil
      expect(Rule.unscoped.where(id: rule_ids).count).to eq(0)
      expect(Reference.where(base_rule_id: rule_ids).count).to eq(0)
      expect(Audited::Audit.where(auditable_type: 'BaseRule', auditable_id: rule_ids).count).to eq(0)
      expect(Review.where(rule_id: rule_ids).count).to eq(0)
    end

    # An SRG component's requirements are authored SrgRules — a Rule-scoped
    # id collection is empty for them, so the bulk cleanup silently no-ops
    # and deletion falls to the per-row cascade: different semantics (the
    # cascade leaves per-row audit events the bulk path deletes) and a perf
    # cliff for large components. Both kinds must take the same fast path.
    context 'with an SRG component' do
      it 'bulk-cleans authored requirements through the same fast path as STIG' do
        doomed = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                 prefix: 'DSTR-00', name: 'Destroy SRG', title: 'Destroy SRG')
        row = create(:srg_rule, :authored, component: doomed, rule_id: '000001',
                                           title: 'Doomed requirement')
        Check.create!(base_rule: row, content: 'doomed check content')
        DisaRuleDescription.create!(base_rule: row, vuln_discussion: 'doomed discussion')
        Reference.create!(base_rule_id: row.id, title: 'doomed reference')
        create(:review, :comment, user: user, rule: nil, commentable: row,
                                  comment: 'doomed comment', section: 'fixtext')
        # A relocated-away requirement carries a source-side relocation record
        # whose foreign key RESTRICTS deletes — the bulk list must clear it.
        RequirementRelocation.create!(source_rule: row, target_technology_token: 'CTR')
        row_id = row.id

        delete "/components/#{doomed.id}", headers: { 'Accept' => application_json }

        expect(response).to have_http_status(:success)
        expect(Component.find_by(id: doomed.id)).to be_nil
        expect(BaseRule.unscoped.where(id: row_id).count).to eq(0)
        expect(Review.where(rule_id: row_id).count).to eq(0)
        expect(Review.where(commentable_type: 'BaseRule', commentable_id: row_id).count).to eq(0)
        expect(Check.where(base_rule_id: row_id).count).to eq(0)
        expect(DisaRuleDescription.where(base_rule_id: row_id).count).to eq(0)
        expect(Reference.where(base_rule_id: row_id).count).to eq(0)
        expect(RequirementRelocation.where(source_rule_id: row_id).count).to eq(0)
        # The same-semantics pin: the fast path deletes the requirements'
        # audit rows wholesale; the cascade leaves them (plus fresh per-row
        # destroy events) behind. Vacuous while suite auditing is disabled,
        # kept as the production-semantics statement of record.
        expect(Audited::Audit.where(auditable_type: 'BaseRule', auditable_id: row_id).count).to eq(0)
      end

      it 'issues a query count invariant to the requirement count' do
        small = build_srg_component('DSQA-00', rows: 2)
        large = build_srg_component('DSQB-00', rows: 8)

        warm_session
        # The first destroy in a process can pay one-time lazy-initialization
        # queries; burn them on a sacrificial destroy so the measured counts
        # compare steady-state work only.
        destroy_query_count(build_srg_component('DSQW-00', rows: 1))
        small_count = destroy_query_count(small)
        large_count = destroy_query_count(large)

        expect(large_count).to eq(small_count),
                               "SRG destroy scales with requirement count: #{small_count} queries " \
                               "for 2 requirements, #{large_count} for 8 — the per-row cascade is running"
      end
    end

    context 'query invariance for STIG components' do
      it 'issues a query count invariant to the rule count' do
        # The shared SRG import gives every component the same full rule set,
        # so the axis is built by deleting rules from one copy — same pattern
        # as the serialization invariance specs.
        small = create(:component, project: project)
        keep = small.rules.order(:id).limit(2).ids
        doomed_rows = Rule.unscoped.where(component_id: small.id).where.not(id: keep)
        Check.where(base_rule_id: doomed_rows.select(:id)).delete_all
        DisaRuleDescription.where(base_rule_id: doomed_rows.select(:id)).delete_all
        RuleDescription.where(base_rule_id: doomed_rows.select(:id)).delete_all
        Reference.where(base_rule_id: doomed_rows.select(:id)).delete_all
        doomed_rows.delete_all
        large = create(:component, project: project)

        large_rule_count = large.rules.count
        warm_session
        # Same steady-state warm-up as the SRG invariance example above.
        destroy_query_count(create(:component, project: project))
        small_count = destroy_query_count(small)
        large_count = destroy_query_count(large)

        expect(large_count).to eq(small_count),
                               "STIG destroy scales with rule count: #{small_count} queries for 2 rules, " \
                               "#{large_count} for #{large_rule_count} — the per-row cascade is running"
      end
    end

    context 'as project author (not admin)' do
      let(:author_user) { create(:user) }

      before do
        Membership.create!(user: author_user, membership: project, role: 'author')
        sign_in author_user
      end

      it 'rejects — destroy requires admin' do
        delete "/components/#{component.id}", headers: { 'Accept' => application_json }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      before { sign_out user }

      it 'redirects to sign-in' do
        delete "/components/#{component.id}", headers: { 'Accept' => application_json }
        expect(response).to have_http_status(:unauthorized)
          .or redirect_to(new_user_session_path)
      end
    end
  end
end
