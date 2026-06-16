# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'container_srg:backfill_adnm' do
  before(:all) do
    Rails.application.load_tasks
  end

  let_it_be(:srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_Web_Server_SRG_V4R4_Manual-xccdf.xml').read
    parsed = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed)
    srg.xml = srg_xml
    srg.save!
    srg
  end

  let_it_be(:project) { Project.create!(name: 'Backfill Test') }
  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:viewer) { create(:user) }

  let_it_be(:component) do
    Component.create!(project: project, name: 'Test SRG', title: 'Test SRG',
                      version: 'V1R1', prefix: 'TEST-BF', based_on: srg)
  end

  let_it_be(:parent_rule) do
    component.rules.find_by(rule_id: component.rules.first.rule_id) ||
      Rule.create!(component: component, rule_id: 'BF-PARENT',
                   status: 'Applicable - Configurable', rule_severity: 'medium',
                   srg_rule: srg.srg_rules.first)
  end

  let_it_be(:child_rule) do
    Rule.create!(component: component, rule_id: 'BF-CHILD',
                 status: 'Applicable - Configurable', rule_severity: 'medium',
                 srg_rule: srg.srg_rules.second)
  end

  before_all do
    Membership.find_or_create_by!(user: admin, membership: project) { |m| m.role = 'admin' }
    Membership.find_or_create_by!(user: viewer, membership: project) { |m| m.role = 'viewer' }
    RuleSatisfaction.find_or_create_by!(rule_id: child_rule.id, satisfied_by_rule_id: parent_rule.id)
  end

  before do
    child_rule.update_columns(status: 'Applicable - Configurable', status_justification: nil)
  end

  it 'sets ADNM on children with wrong status (dry-run reports only)' do
    stub_const('ENV', ENV.to_h.merge('COMPONENT_ID' => component.id.to_s))

    expect do
      Rake::Task['container_srg:backfill_adnm'].reenable
      Rake::Task['container_srg:backfill_adnm'].invoke
    end.to output(/DRY RUN/).to_stdout

    child_rule.reload
    expect(child_rule.status).to eq('Applicable - Configurable')
  end

  it 'sets ADNM on children when EXECUTE=true' do
    stub_const('ENV', ENV.to_h.merge('EXECUTE' => 'true', 'COMPONENT_ID' => component.id.to_s))

    expect do
      Rake::Task['container_srg:backfill_adnm'].reenable
      Rake::Task['container_srg:backfill_adnm'].invoke
    end.to output(/EXECUTING/).to_stdout

    child_rule.reload
    expect(child_rule.status).to eq('Applicable - Does Not Meet')
    expect(child_rule.status_justification).to include(parent_rule.rule_id)
  end

  it 'auto-adjudicates pending comments on children as addressed_by' do
    comment = create(:review, :comment, comment: 'child concern', section: nil,
                                        user: viewer, rule: parent_rule)
    comment.update_columns(rule_id: child_rule.id, commentable_id: child_rule.id)

    stub_const('ENV', ENV.to_h.merge('EXECUTE' => 'true', 'COMPONENT_ID' => component.id.to_s))

    Rake::Task['container_srg:backfill_adnm'].reenable
    Rake::Task['container_srg:backfill_adnm'].invoke

    comment.reload
    expect(comment.triage_status).to eq('addressed_by')
    expect(comment.addressed_by_rule_id).to eq(parent_rule.id)
    expect(comment.adjudicated_at).to be_present
  end

  it 'creates a response comment explaining the addressed_by disposition' do
    comment = create(:review, :comment, comment: 'child concern', section: nil,
                                        user: viewer, rule: parent_rule)
    comment.update_columns(rule_id: child_rule.id, commentable_id: child_rule.id)

    stub_const('ENV', ENV.to_h.merge('EXECUTE' => 'true', 'COMPONENT_ID' => component.id.to_s))

    Rake::Task['container_srg:backfill_adnm'].reenable
    Rake::Task['container_srg:backfill_adnm'].invoke

    response = Review.find_by(responding_to_review_id: comment.id)
    expect(response).to be_present
    expect(response.comment).to include(parent_rule.rule_id)
    expect(response.user_id).to eq(admin.id)
  end

  it 'is idempotent — skips already-ADNM children and already-triaged comments' do
    child_rule.apply_nesting_status!(parent_rule)
    comment = create(:review, :comment, comment: 'already triaged', section: nil,
                                        user: viewer, rule: parent_rule)
    comment.update_columns(rule_id: child_rule.id, commentable_id: child_rule.id)
    comment.update!(triage_status: 'concur', triage_set_by_id: admin.id, triage_set_at: Time.current)

    stub_const('ENV', ENV.to_h.merge('EXECUTE' => 'true', 'COMPONENT_ID' => component.id.to_s))

    expect do
      Rake::Task['container_srg:backfill_adnm'].reenable
      Rake::Task['container_srg:backfill_adnm'].invoke
    end.to output(/Already ADNM: 1/).to_stdout

    comment.reload
    expect(comment.triage_status).to eq('concur')
  end
end
