# frozen_string_literal: true

require 'rails_helper'

# Storage seam for SRG component authoring.
#
# REQUIREMENTS these specs verify (not implementation):
# - An SrgRule is AUTHORED (component-linked, no catalog parent) XOR
#   CATALOG (catalog-linked, no component) — both or neither is rejected
#   at the model layer AND by a type-scoped database CHECK that leaves
#   Rule/StigRule rows unconstrained.
# - SrgRule soft-delete default scope mirrors Rule's — deleted rows leave
#   every SrgRule query; catalog reads are otherwise unchanged. The scope
#   lives on SrgRule, never BaseRule.
# - derived_from resolves the catalog row an authored requirement was
#   derived from.
# - Authored SrgRules are audited like Rules, associated with their
#   component.
RSpec.describe SrgRule do
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, :skip_rules, document_type: 'srg') }

  describe 'authored XOR catalog (model validation)' do
    it 'accepts a catalog SrgRule — catalog parent set, no component' do
      rule = build(:srg_rule, security_requirements_guide: srg)

      expect(rule.component_id).to be_nil
      expect(rule).to be_valid
    end

    it 'accepts an authored SrgRule — component set, no catalog parent' do
      rule = build(:srg_rule, :authored, component: component)

      expect(rule.security_requirements_guide_id).to be_nil
      expect(rule).to be_valid
    end

    it 'rejects a dual-linked SrgRule — both component and catalog parent set' do
      rule = build(:srg_rule, security_requirements_guide: srg, component: component)

      expect(rule).not_to be_valid
      expect(rule.errors[:base])
        .to include('must belong to either a component (authored) or a security requirements guide (catalog), not both')
    end

    it 'rejects an orphan SrgRule — neither component nor catalog parent set' do
      rule = build(:srg_rule, security_requirements_guide: nil)

      expect(rule).not_to be_valid
      expect(rule.errors[:base])
        .to include('must belong to either a component (authored) or a security requirements guide (catalog), not both')
    end

    # REQUIREMENT: "authored" is decided by the association, not just the
    # FK column — during a nested build (component copy) the parent is
    # unsaved so component_id is still nil while the component association
    # is set. A column-only test misclassified copied authored rows as
    # catalog rows (XOR failure + wrong status vocabulary).
    it 'treats a nested-built row (unsaved parent, association set) as authored' do
      unsaved_parent = Component.new(project: component.project, name: 'Nested Parent',
                                     prefix: 'NEST-00', title: 'Nested', document_type: 'srg',
                                     based_on: component.based_on)
      rule = build(:srg_rule, :authored, component: unsaved_parent, status: 'Applicable')

      expect(rule.component_id).to be_nil
      expect(rule).to be_valid
    end

    it 'validates a nested-built authored row against the profile vocabulary, not the legacy list' do
      unsaved_parent = Component.new(project: component.project, name: 'Nested Vocab',
                                     prefix: 'NESV-00', title: 'Nested vocab', document_type: 'srg',
                                     based_on: component.based_on)
      rule = build(:srg_rule, :authored, component: unsaved_parent,
                                         status: 'Applicable - Configurable')

      expect(rule).not_to be_valid
      expect(rule.errors[:status].join)
        .to include("acceptable values are: 'Not Yet Determined', 'Applicable', 'Not Applicable'")
    end
  end

  describe 'authored XOR catalog (database CHECK — survives validation bypass)' do
    it 'blocks dual-linking an authored row even via update_columns' do
      rule = create(:srg_rule, :authored, component: component)

      expect { rule.update_columns(security_requirements_guide_id: srg.id) }
        .to raise_error(ActiveRecord::StatementInvalid, /base_rules_srg_authored_xor_catalog/)
    end

    it 'blocks orphaning an authored row even via update_columns' do
      rule = create(:srg_rule, :authored, component: component)

      expect { rule.update_columns(component_id: nil) }
        .to raise_error(ActiveRecord::StatementInvalid, /base_rules_srg_authored_xor_catalog/)
    end

    it 'does not constrain StigRule rows, which carry neither FK' do
      stig_rule = create(:stig_rule)

      expect(stig_rule.component_id).to be_nil
      expect(stig_rule.security_requirements_guide_id).to be_nil
      expect(stig_rule).to be_persisted
    end
  end

  describe 'soft-delete default scope' do
    it 'excludes a soft-deleted SrgRule from default queries but keeps it in unscoped' do
      rule = create(:srg_rule, :authored, component: component)
      rule.update_column(:deleted_at, Time.current)

      expect(described_class.where(id: rule.id)).to be_empty
      expect(described_class.unscoped.where(id: rule.id).count).to eq(1)
    end

    it 'excludes a soft-deleted catalog row from the SRG association' do
      catalog_rule = create(:srg_rule, security_requirements_guide: srg)
      expect(srg.srg_rules.where(id: catalog_rule.id).count).to eq(1)

      catalog_rule.update_column(:deleted_at, Time.current)

      expect(srg.reload.srg_rules.where(id: catalog_rule.id)).to be_empty
    end

    it 'does NOT extend to StigRule — the scope lives on SrgRule, not BaseRule' do
      stig_rule = create(:stig_rule)
      stig_rule.update_column(:deleted_at, Time.current)

      expect(StigRule.where(id: stig_rule.id).count).to eq(1)
    end
  end

  describe 'authored status vocabulary (per-profile)' do
    it 'accepts every SRG-vocabulary status on an authored row' do
      # Not Applicable carries its lifecycle requirement: the decision's
      # justification (see the Not Applicable justification examples).
      ['Not Yet Determined', 'Applicable', 'Not Applicable'].each do |status|
        justification = status == 'Not Applicable' ? 'Decided out of scope' : nil
        rule = build(:srg_rule, :authored, component: component, status: status,
                                           status_justification: justification)
        expect(rule).to be_valid, "expected authored row with status #{status.inspect} to be valid"
      end
    end

    it 'rejects STIG-only statuses on an authored row — exact-match inclusion' do
      rule = build(:srg_rule, :authored, component: component,
                                         status: 'Applicable - Configurable')

      expect(rule).not_to be_valid
      expect(rule.errors[:status])
        .to include("is not an acceptable value, acceptable values are: 'Not Yet Determined', " \
                    "'Applicable', 'Not Applicable'")
    end

    it 'keeps the legacy superset for catalog rows — ingest statuses unchanged' do
      catalog_rule = build(:srg_rule, security_requirements_guide: srg,
                                      status: 'Applicable - Configurable')
      expect(catalog_rule).to be_valid

      bare = build(:srg_rule, security_requirements_guide: srg, status: 'Applicable')
      expect(bare).not_to be_valid
    end
  end

  describe '#derived_from' do
    it 'resolves the catalog row an authored requirement was derived from' do
      catalog_rule = create(:srg_rule, security_requirements_guide: srg)
      authored = create(:srg_rule, :authored, component: component,
                                              derived_from_srg_rule_id: catalog_rule.id)

      expect(authored.derived_from).to eq(catalog_rule)
    end

    it 'nullifies the reference when the catalog row is removed — authored rows survive' do
      catalog_rule = create(:srg_rule, security_requirements_guide: srg)
      authored = create(:srg_rule, :authored, component: component,
                                              derived_from_srg_rule_id: catalog_rule.id)

      catalog_rule.delete

      expect(authored.reload.derived_from_srg_rule_id).to be_nil
      expect(authored.derived_from).to be_nil
    end
  end

  describe 'audit wiring' do
    include_context 'with auditing'

    it 'audits authored SrgRule creation and updates, associated with the component' do
      authored = create(:srg_rule, :authored, component: component)
      expect(authored.audits.count).to eq(1)
      expect(authored.audits.first.action).to eq('create')

      expect { authored.update!(title: 'Updated authored title') }
        .to change { authored.audits.count }.by(1)

      audit = authored.audits.last
      expect(audit.audited_changes.keys).to eq(['title'])
      expect(audit.associated).to eq(component)
    end

    it 'does not audit bulk catalog imports — SrgRule.import bypasses callbacks' do
      rows = [build(:srg_rule, security_requirements_guide: srg)]

      expect { described_class.import(rows, all_or_none: true, recursive: true) }
        .not_to change(Audited::Audit, :count)
    end
  end

  # REQUIREMENT (SRG lifecycle): marking an authored requirement Not
  # Applicable records a decision — the justification IS the record, so
  # it is required at the model layer. Catalog rows and the other
  # authored statuses are untouched.
  describe 'Not Applicable justification (authored rows only)' do
    it 'rejects an authored NA row without a status_justification' do
      rule = build(:srg_rule, :authored, component: component,
                                         status: 'Not Applicable', status_justification: nil)

      expect(rule).not_to be_valid
      expect(rule.errors.full_messages)
        .to include('Status justification is required when the requirement is Not Applicable')
    end

    it 'rejects an authored NA row with a blank status_justification' do
      rule = build(:srg_rule, :authored, component: component,
                                         status: 'Not Applicable', status_justification: '   ')

      expect(rule).not_to be_valid
      expect(rule.errors[:status_justification])
        .to include('is required when the requirement is Not Applicable')
    end

    it 'accepts an authored NA row with a justification' do
      rule = build(:srg_rule, :authored, component: component,
                                         status: 'Not Applicable',
                                         status_justification: 'Container platforms have no wireless interfaces')

      expect(rule).to be_valid
    end

    it 'accepts authored Applicable and Not Yet Determined rows without a justification' do
      ['Applicable', 'Not Yet Determined'].each do |status|
        rule = build(:srg_rule, :authored, component: component,
                                           status: status, status_justification: nil)

        expect(rule).to be_valid, "expected #{status} to be valid without a justification"
      end
    end

    it 'leaves catalog rows unaffected — NA without justification stays valid' do
      rule = build(:srg_rule, security_requirements_guide: srg,
                              status: 'Not Applicable', status_justification: nil)

      expect(rule).to be_valid
    end
  end
end
