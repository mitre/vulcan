# frozen_string_literal: true

require 'rails_helper'

# PR-717 review remediation .4 — F4 forensic correlation primitive.
#
# Audited gem auto-populates `request_uuid` on every audit row created
# during one Rails HTTP request. AuditEventBundle wraps the indexed
# `request_uuid` query so forensic reconstruction of a multi-row admin
# action ("admin destroyed parent + cascaded N replies, all part of one
# operator action") is one ergonomic call instead of an ad-hoc query
# repeated at every call site.
#
# Reachable via `Audited::Audit.bundled_with(audit_id)` class method.
RSpec.describe AuditEventBundle do
  let_it_be(:srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_Web_Server_SRG_V4R4_Manual-xccdf.xml').read
    srg = SecurityRequirementsGuide.from_mapping(Xccdf::Benchmark.parse(srg_xml))
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let_it_be(:project) { Project.create!(name: 'AEB Project') }
  let_it_be(:component) do
    Component.create!(project: project, name: 'AEB Comp', title: 'AEB Comp Title',
                      version: 'v1', prefix: 'AEBX-01', based_on: srg)
  end
  let_it_be(:rule) do
    Rule.create!(component: component, rule_id: 'AEBX-01-1', status: 'Applicable - Configurable',
                 rule_severity: 'medium', srg_rule: srg.srg_rules.first)
  end
  let_it_be(:user) { create(:user, admin: true) }

  let(:request_uuid) { SecureRandom.uuid }

  before do
    # Set up 4 audit rows: 1 trigger (Component-level), 1 parent destroy,
    # 2 child destroys — all sharing one request_uuid (mimics what audited
    # does inside a single Rails request for admin_destroy + cascade).
    @trigger = VulcanAudit.create!(
      action: 'admin_destroy_review', auditable: component,
      user: user, request_uuid: request_uuid,
      comment: 'Admin hard-delete review 1: PII removal — legal request',
      audited_changes: { 'review_id' => 1, 'reply_count' => 2 }
    )
    @parent_destroy = VulcanAudit.create!(
      action: 'destroy', auditable_type: 'Review', auditable_id: 1,
      user: user, request_uuid: request_uuid,
      audited_changes: { 'comment' => ['parent', nil] }
    )
    @child1_destroy = VulcanAudit.create!(
      action: 'destroy', auditable_type: 'Review', auditable_id: 2,
      user: user, request_uuid: request_uuid,
      audited_changes: { 'comment' => ['child 1', nil] }
    )
    @child2_destroy = VulcanAudit.create!(
      action: 'destroy', auditable_type: 'Review', auditable_id: 3,
      user: user, request_uuid: request_uuid,
      audited_changes: { 'comment' => ['child 2', nil] }
    )
    # Unrelated audit (different request_uuid) to prove filter scope
    @unrelated = VulcanAudit.create!(
      action: 'update', auditable: component,
      user: user, request_uuid: SecureRandom.uuid
    )
  end

  describe '#trigger' do
    it 'returns the audit row used to construct the bundle' do
      bundle = described_class.new(@trigger)
      expect(bundle.trigger).to eq(@trigger)
    end
  end

  describe '#related' do
    it 'returns every audit row sharing the trigger request_uuid' do
      bundle = described_class.new(@trigger)
      expect(bundle.related).to contain_exactly(@trigger, @parent_destroy, @child1_destroy, @child2_destroy)
      expect(bundle.related).not_to include(@unrelated)
    end
  end

  describe '#destroyed_reviews' do
    it 'returns only the Review-destroy audit rows from the bundle' do
      bundle = described_class.new(@trigger)
      expect(bundle.destroyed_reviews).to contain_exactly(@parent_destroy, @child1_destroy, @child2_destroy)
    end

    it 'is empty when no Review destroys are in the request' do
      lone_audit = VulcanAudit.create!(
        action: 'update', auditable: component, user: user,
        request_uuid: SecureRandom.uuid
      )
      expect(described_class.new(lone_audit).destroyed_reviews).to be_empty
    end
  end

  describe '#destroyed_review_count' do
    it 'returns the integer count' do
      expect(described_class.new(@trigger).destroyed_review_count).to eq(3)
    end
  end

  describe '#to_h' do
    it 'returns a hash with trigger_id, request_uuid, related_count, destroyed_review_ids' do
      h = described_class.new(@trigger).to_h
      expect(h).to include(
        trigger_id: @trigger.id,
        request_uuid: request_uuid,
        related_count: 4,
        destroyed_review_ids: contain_exactly(1, 2, 3)
      )
    end
  end

  describe 'when trigger has nil request_uuid' do
    it 'returns just the trigger in #related and is empty in #destroyed_reviews' do
      orphan = VulcanAudit.create!(action: 'update', auditable: component,
                                   user: user, request_uuid: nil)
      bundle = described_class.new(orphan)
      expect(bundle.related).to contain_exactly(orphan)
      expect(bundle.destroyed_reviews).to be_empty
    end
  end

  describe 'VulcanAudit.bundled_with' do
    it 'looks up the trigger by id and returns an AuditEventBundle' do
      bundle = VulcanAudit.bundled_with(@trigger.id)
      expect(bundle).to be_a(described_class)
      expect(bundle.trigger).to eq(@trigger)
      expect(bundle.destroyed_review_count).to eq(3)
    end
  end
end
