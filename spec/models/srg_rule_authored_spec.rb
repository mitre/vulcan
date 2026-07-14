# frozen_string_literal: true

require 'rails_helper'

# Storage seam for SRG component authoring (ADR
# docs/decisions/adr-srg-component-authoring.md §3, §6, §8.2, §12.1).
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
  let_it_be(:component) { create(:component, :skip_rules) }

  describe 'authored XOR catalog (model validation)' do
    it 'accepts a catalog SrgRule — catalog parent set, no component' do
      rule = build(:srg_rule, security_requirements_guide: srg)

      expect(rule.component_id).to be_nil
      expect(rule).to be_valid
    end

    it 'accepts an authored SrgRule — component set, no catalog parent' do
      rule = build(:srg_rule, security_requirements_guide: nil, component: component)

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
  end

  describe 'authored XOR catalog (database CHECK — survives validation bypass)' do
    it 'blocks dual-linking an authored row even via update_columns' do
      rule = create(:srg_rule, security_requirements_guide: nil, component: component)

      expect { rule.update_columns(security_requirements_guide_id: srg.id) }
        .to raise_error(ActiveRecord::StatementInvalid, /base_rules_srg_authored_xor_catalog/)
    end

    it 'blocks orphaning an authored row even via update_columns' do
      rule = create(:srg_rule, security_requirements_guide: nil, component: component)

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
      rule = create(:srg_rule, security_requirements_guide: nil, component: component)
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

  describe '#derived_from' do
    it 'resolves the catalog row an authored requirement was derived from' do
      catalog_rule = create(:srg_rule, security_requirements_guide: srg)
      authored = create(:srg_rule, security_requirements_guide: nil, component: component,
                                   derived_from_srg_rule_id: catalog_rule.id)

      expect(authored.derived_from).to eq(catalog_rule)
    end

    it 'nullifies the reference when the catalog row is removed — authored rows survive' do
      catalog_rule = create(:srg_rule, security_requirements_guide: srg)
      authored = create(:srg_rule, security_requirements_guide: nil, component: component,
                                   derived_from_srg_rule_id: catalog_rule.id)

      catalog_rule.delete

      expect(authored.reload.derived_from_srg_rule_id).to be_nil
      expect(authored.derived_from).to be_nil
    end
  end

  describe 'audit wiring' do
    include_context 'with auditing'

    it 'audits authored SrgRule creation and updates, associated with the component' do
      authored = create(:srg_rule, security_requirements_guide: nil, component: component)
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
end
