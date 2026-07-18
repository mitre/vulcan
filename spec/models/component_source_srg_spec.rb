# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT (multi-parent derivation): based_on IS the primary parent and
# must be a member of the component_source_srgs join set; assigning based_on
# reconciles the join atomically — replacing a superseded SAME-FAMILY member
# (family = srg_id, version-tolerant) and never appending unbounded; parent
# eligibility comes from the AuthoringProfile registry policy (SRG-kind
# parents must be core families, STIG-kind parents derived/non-core); and
# the family invariant — every sourced live requirement belongs to a
# parent-set family — guards parent removal.
RSpec.describe ComponentSourceSrg do
  let_it_be(:project) { create(:project) }
  # Family A in two versions (same srg_id) + an unrelated family B.
  let_it_be(:fam_a_v1) do
    create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-FAM-A', version: 'V1R1')
  end
  let_it_be(:fam_a_v2) do
    create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-FAM-A', version: 'V1R2')
  end
  let_it_be(:fam_b) do
    create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-FAM-B', version: 'V1R1')
  end
  let_it_be(:core_srg) do
    create(:security_requirements_guide, :skip_rules, :core, srg_id: 'SRG-CORE-OS', version: 'V1R1')
  end

  def stig_component(based_on: fam_a_v1)
    create(:component, :skip_rules, project: project, based_on: based_on, prefix: 'PSET-00')
  end

  describe 'join model' do
    it 'rejects a duplicate (component, srg) pair' do
      component = stig_component
      dup = described_class.new(component: component, security_requirements_guide: fam_a_v1)
      expect(dup).not_to be_valid
      expect(dup.errors[:security_requirements_guide_id]).to include('has already been taken')
    end
  end

  describe 'based_on membership and reconciliation' do
    it 'creating a component inserts its based_on into the join set' do
      component = stig_component
      expect(component.source_srgs.reload).to contain_exactly(fam_a_v1)
    end

    it 'reassigning based_on to a newer same-family version REPLACES the superseded member' do
      component = stig_component
      component.update!(based_on: fam_a_v2)
      expect(component.source_srgs.reload).to contain_exactly(fam_a_v2)
    end

    it 'leaves a different-family secondary untouched by same-family replacement' do
      component = stig_component
      component.component_source_srgs.create!(security_requirements_guide: fam_b)
      component.update!(based_on: fam_a_v2)
      expect(component.source_srgs.reload).to contain_exactly(fam_a_v2, fam_b)
    end

    it 'reassigning based_on to a NEW family adds it and keeps the prior family as a declared parent' do
      component = stig_component
      component.update!(based_on: fam_b)
      expect(component.source_srgs.reload).to contain_exactly(fam_a_v1, fam_b)
    end

    it 'self-heals a missing based_on join row on the next save' do
      component = stig_component
      component.component_source_srgs.reload
      # Simulate a corrupted state: membership row destroyed out from under
      # based_on (delete bypasses the destroy guard deliberately — the
      # validation is the second line of defense).
      component.component_source_srgs.where(security_requirements_guide: fam_a_v1).delete_all
      component.component_source_srgs.reload
      component.name = 'renamed'
      # Reconciliation self-heals on the next save: the based_on row is
      # re-inserted rather than failing the save.
      expect(component.save).to be true
      expect(component.source_srgs.reload).to include(fam_a_v1)
    end
  end

  describe 'parent eligibility (AuthoringProfile policy)' do
    it 'rejects an srg-kind component with a non-core parent' do
      component = build(:component, :skip_rules, project: project, document_type: 'srg',
                                                 based_on: fam_a_v1, prefix: 'PSET-01',
                                                 name: 'SRG bad parent', title: 'SRG bad parent')
      expect(component).not_to be_valid
      expect(component.errors[:base].join).to match(/core/i)
    end

    it 'accepts an srg-kind component with a core parent' do
      component = build(:component, :skip_rules, project: project, document_type: 'srg',
                                                 based_on: core_srg, prefix: 'PSET-02',
                                                 name: 'SRG good parent', title: 'SRG good parent')
      expect(component).to be_valid
    end

    it 'rejects a stig-kind component with a core parent' do
      component = build(:component, :skip_rules, project: project, based_on: core_srg,
                                                 prefix: 'PSET-03')
      expect(component).not_to be_valid
      expect(component.errors[:base].join).to match(/derived|core/i)
    end

    it 'accepts a stig-kind component with a derived (non-core) parent' do
      expect(build(:component, :skip_rules, project: project, based_on: fam_a_v1,
                                            prefix: 'PSET-04')).to be_valid
    end
  end

  describe 'family invariant guard on parent removal' do
    it 'blocks removing the only member of a family still referenced by live requirements' do
      component = stig_component
      catalog_row = create(:srg_rule, security_requirements_guide: fam_a_v1)
      create(:rule, component: component, srg_rule: catalog_row)
      join_row = component.component_source_srgs.find_by(security_requirements_guide: fam_a_v1)
      expect(join_row.destroy).to be false
      expect(join_row.errors[:base].join).to match(/referenced|family/i)
    end

    it 'allows a same-family version swap while requirements reference the family' do
      component = stig_component
      catalog_row = create(:srg_rule, security_requirements_guide: fam_a_v1)
      create(:rule, component: component, srg_rule: catalog_row)
      component.update!(based_on: fam_a_v2)
      expect(component.source_srgs.reload).to contain_exactly(fam_a_v2)
    end

    it 'allows removing a parent family no live requirement references' do
      component = stig_component
      component.component_source_srgs.create!(security_requirements_guide: fam_b)
      join_row = component.component_source_srgs.find_by(security_requirements_guide: fam_b)
      expect(join_row.destroy).to be_truthy
      expect(component.source_srgs.reload).to contain_exactly(fam_a_v1)
    end
  end

  describe 'duplicate and the revision flow' do
    it 'copies the parent set on duplicate' do
      component = stig_component
      component.component_source_srgs.create!(security_requirements_guide: fam_b)
      copy = component.duplicate(new_name: 'Copy')
      copy.save!
      expect(copy.source_srgs.reload).to contain_exactly(fam_a_v1, fam_b)
    end

    it 'revision flow end-to-end: duplicate(new_srg_id:) replaces the family member and keeps old-version sources valid' do
      component = stig_component
      catalog_row = create(:srg_rule, security_requirements_guide: fam_a_v1)
      create(:rule, component: component, srg_rule: catalog_row)
      component.component_source_srgs.create!(security_requirements_guide: fam_b)

      revision = component.duplicate(new_name: 'Revision', new_srg_id: fam_a_v2.id)
      revision.save!

      expect(revision.based_on).to eq(fam_a_v2)
      expect(revision.source_srgs.reload).to contain_exactly(fam_a_v2, fam_b)
      # Version-tolerant invariant: the copied rule still sources the OLD
      # catalog row (kept by design) — same family, so the set is valid.
      expect(revision.source_srgs.map(&:srg_id)).to include(catalog_row.security_requirements_guide.srg_id)
    end
  end
end
