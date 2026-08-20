# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review do
  include_context 'srg model base setup'
  include_context 'with auditing'

  # section is editable post-creation; the change must show up
  # in the audit log so the disposition record reflects who retagged what + why.
  describe 'section auditing' do
    let!(:section_review) do
      create(:review, :comment, rule: rule, user: p_viewer,
                                comment: 'misclassified', triage_status: 'pending',
                                section: nil)
    end

    it 'records an audit entry when section changes' do
      expect do
        section_review.audit_comment = 'tagging as Check after triager review'
        section_review.update!(section: 'check_content')
      end.to change { section_review.audits.count }.by_at_least(1)
    end

    it 'captures the from→to transition in audited_changes' do
      section_review.audit_comment = 'tagging as Check'
      section_review.update!(section: 'check_content')
      latest = section_review.audits.last
      expect(latest.audited_changes['section']).to eq([nil, 'check_content'])
    end

    it 'preserves the audit comment' do
      section_review.audit_comment = 'tagging as Check after triager review'
      section_review.update!(section: 'check_content')
      expect(section_review.audits.last.comment).to include('Check after triager')
    end
  end

  # vulcan_audited needs associated_with: :rule
  # so audit rows survive admin_destroy as queryable records (auditable_id
  # points to a destroyed Review, but associated_id still points to a valid
  # Rule). All other audited models declare associated_with; Review was the gap.
  # Note: Rule is STI under BaseRule, so audited stores the polymorphic type
  # as the base class name 'BaseRule' but the polymorphic relation still
  # resolves to a Rule instance through STI.
  describe 'audit-trail association via associated_with: :rule' do
    let!(:assoc_review) do
      create(:review, :comment, rule: rule, user: p_viewer,
                                comment: 'something', triage_status: 'pending', section: nil)
    end

    it 'populates associated to the rule on a triage update audit' do
      assoc_review.audit_comment = 'first triage'
      assoc_review.update!(triage_status: 'concur')
      latest = assoc_review.audits.last
      expect(latest.associated_type).to eq('BaseRule')
      expect(latest.associated_id).to eq(rule.id)
    end

    it 'populates associated on the create-time audit row' do
      first_audit = assoc_review.audits.first
      expect(first_audit.associated_type).to eq('BaseRule')
      expect(first_audit.associated_id).to eq(rule.id)
    end

    it 'allows querying rule-scoped audit history independent of auditable' do
      assoc_review.audit_comment = 'note'
      assoc_review.update!(triage_status: 'concur')
      rule_audits = Audited::Audit.where(associated_type: 'BaseRule', associated_id: rule.id)
      expect(rule_audits.where(auditable_type: 'Review', auditable_id: assoc_review.id)).to exist
    end
  end

  describe 'audits' do
    it 'audits triage_status changes' do
      review = create(:review, :comment, comment: 'x', section: nil, user: p_viewer, rule: rule)
      expect do
        review.update!(triage_status: 'concur', triage_set_by_id: p_admin.id, triage_set_at: Time.current)
      end.to change(review.audits, :count).by(1)
      audit = review.audits.last
      expect(audit.audited_changes['triage_status']).to eq(%w[pending concur])
    end
  end
end
