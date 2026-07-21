# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT (relocation as a record, never a status): a PENDING
# requirement_relocations row IS the move marker for an authored SRG
# requirement — one pending marker per source, unlimited executed history;
# executed records are immutable to users; the source rule hard-destroy
# cascades its records while target destruction only nullifies.
RSpec.describe RequirementRelocation do
  let_it_be(:core_srg) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-RELOC', version: 'V1R1')
  end
  let_it_be(:srg_component) do
    create(:component, :skip_rules, document_type: 'srg', based_on: core_srg, prefix: 'RELO-00')
  end
  let_it_be(:requester) { create(:user) }

  def authored_row(rule_id)
    create(:srg_rule, :authored, component: srg_component, rule_id: rule_id)
  end

  describe 'one pending marker per source' do
    it 'rejects a second pending relocation for the same source rule' do
      source = authored_row('900001')
      described_class.create!(source_rule: source, target_technology_token: 'CTR',
                              requested_by: requester)

      duplicate = described_class.new(source_rule: source, target_technology_token: 'GPOS',
                                      requested_by: requester)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:source_rule_id].join).to match(/pending/i)
    end

    it 'allows a pending and an executed record to coexist for the same source' do
      source = authored_row('900002')
      source.update!(deleted_at: Time.current)
      described_class.create!(source_rule: source, target_technology_token: 'CTR',
                              requested_by: requester, executed_at: 1.day.ago)

      pending_again = described_class.new(source_rule: source, target_technology_token: 'GPOS',
                                          requested_by: requester)
      expect(pending_again).to be_valid
    end
  end

  describe 'source eligibility (SRG authoring, source side only)' do
    it 'rejects a catalog SrgRule as the source' do
      catalog_row = create(:srg_rule, security_requirements_guide: core_srg, version: 'SRG-X-900101')
      record = described_class.new(source_rule: catalog_row, target_technology_token: 'CTR')

      expect(record).not_to be_valid
      expect(record.errors[:source_rule].join).to match(/authored requirement of an SRG component/)
    end

    it 'rejects a stig-kind Rule as the source' do
      stig_component = create(:component, :skip_rules, prefix: 'RELS-00')
      rule = create(:rule, component: stig_component)
      record = described_class.new(source_rule_id: rule.id, target_technology_token: 'CTR')

      expect(record).not_to be_valid
      expect(record.errors[:source_rule].join).to match(/must exist/)
    end
  end

  describe 'executed records are immutable to users' do
    it 'rejects any update to an executed record' do
      source = authored_row('900003')
      source.update!(deleted_at: Time.current)
      executed = described_class.create!(source_rule: source, target_technology_token: 'CTR',
                                         executed_at: 1.day.ago)

      executed.target_technology_token = 'GPOS'
      expect(executed.save).to be false
      expect(executed.errors[:base].join).to match(/immutable/)
    end

    it 'permits the pending-to-executed transition once the source is tombstoned (the executor path)' do
      source = authored_row('900004')
      record = described_class.create!(source_rule: source, target_technology_token: 'CTR')

      source.update!(deleted_at: Time.current)
      record.executed_at = Time.current
      expect(record.save).to be true
    end
  end

  describe 'deletion interactions' do
    it 'hard-destroy of the source rule cascades its records, pending and executed alike' do
      source = authored_row('900005')
      pending = described_class.create!(source_rule: source, target_technology_token: 'CTR')
      source.update!(deleted_at: Time.current)
      executed = described_class.create!(source_rule: source, target_technology_token: 'GPOS',
                                         executed_at: 1.day.ago)

      source.destroy!

      expect(described_class.where(id: [pending.id, executed.id]).count).to eq(0)
    end

    it 'nullifies target_rule_id when the landed target row is destroyed' do
      source = authored_row('900006')
      target = authored_row('900007')
      source.update!(deleted_at: Time.current)
      executed = described_class.create!(source_rule: source, target_technology_token: 'CTR',
                                         target_rule: target, executed_at: 1.day.ago)

      target.destroy!

      expect(executed.reload.target_rule_id).to be_nil
    end
  end

  describe 'backlog and lifecycle counts' do
    it 'backlog_for returns only pending markers for the token' do
      a = authored_row('900008')
      b = authored_row('900009')
      c = authored_row('900010')
      ctr_pending = described_class.create!(source_rule: a, target_technology_token: 'CTR')
      described_class.create!(source_rule: b, target_technology_token: 'GPOS')
      c.update!(deleted_at: Time.current)
      described_class.create!(source_rule: c, target_technology_token: 'CTR',
                              executed_at: 1.day.ago)

      expect(described_class.backlog_for('CTR')).to contain_exactly(ctr_pending)
    end

    it 'counts moved-out requirements from executed records on the component' do
      source = authored_row('900011')
      source.update!(deleted_at: Time.current)
      described_class.create!(source_rule: source, target_technology_token: 'CTR',
                              executed_at: 1.day.ago)
      other = authored_row('900012')
      described_class.create!(source_rule: other, target_technology_token: 'CTR')

      expect(srg_component.moved_out_count).to eq(1)
    end
  end

  describe 'auditing' do
    include_context 'with auditing'

    it 'audits marker creation and un-marking, associated with the component' do
      source = authored_row('900013')
      record = described_class.create!(source_rule: source, target_technology_token: 'CTR')
      record.destroy!

      audits = Audited::Audit.where(auditable_type: 'RequirementRelocation', auditable_id: record.id)
      expect(audits.pluck(:action)).to contain_exactly('create', 'destroy')
      expect(audits.pluck(:associated_id)).to all(eq(srg_component.id))
      expect(audits.pluck(:associated_type)).to all(eq('Component'))
    end
  end
end
