# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT (accepting a relocation proposal): acceptance and landing
# are ONE action and ONE transaction — create/link the target
# requirement in the destination component, stamp executed_at plus the
# accepting actor, tombstone the source row — rolling back atomically on
# any step failure. Dry-run previews the same move with zero writes.
# Declined or executed proposals are no longer open and cannot land.
# Reviews stay frozen on the tombstone; counts and duplication never
# resurrect it.
RSpec.describe RelocationExecutor do
  let_it_be(:core_os) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-EXEC-OS', version: 'V1R1')
  end
  let_it_be(:core_app) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-EXEC-APP', version: 'V1R1')
  end
  let_it_be(:project) { create(:project) }
  let_it_be(:requester) { create(:user) }

  def srg_component(prefix, based_on)
    create(:component, :skip_rules, project: project, document_type: 'srg',
                                    based_on: based_on, prefix: prefix)
  end

  def authored_row(component, rule_id, derived_from: nil)
    create(:srg_rule, :authored, component: component, rule_id: rule_id,
                                 derived_from_srg_rule_id: derived_from&.id)
  end

  describe '#execute!' do
    it 'creates the target, stamps executed_at, tombstones the source — atomically' do
      catalog_row = create(:srg_rule, security_requirements_guide: core_os, version: 'SRG-OS-000301')
      source_component = srg_component('EXSC-00', core_os)
      target_component = srg_component('EXTC-00', core_os)
      source = authored_row(source_component, '300001', derived_from: catalog_row)
      relocation = RequirementRelocation.create!(source_rule: source,
                                                 target_technology_token: 'EXTC',
                                                 requested_by: requester)

      result = described_class.new(relocation, target_component: target_component,
                                               accepted_by: requester).execute!

      target = result.target_rule
      expect(target.component_id).to eq(target_component.id)
      expect(target.derived_from_srg_rule_id).to eq(catalog_row.id)
      expect(target.title).to eq(source.title)
      expect(target.security_requirements_guide_id).to be_nil

      relocation.reload
      expect(relocation.executed_at).to be_present
      expect(relocation.target_rule_id).to eq(target.id)
      # Acceptance provenance is stamped in the same transaction.
      expect(relocation.accepted_by).to eq(requester)
      expect(relocation.accepted_at).to be_present

      # Tombstoned: gone from the live scope, present unscoped.
      expect(target_component.authored_srg_rules.pluck(:id)).to include(target.id)
      expect(source_component.authored_srg_rules.pluck(:id)).not_to include(source.id)
      expect(SrgRule.unscoped.find(source.id).deleted_at).to be_present
    end

    it 'rolls back every step when a late step fails' do
      catalog_row = create(:srg_rule, security_requirements_guide: core_os, version: 'SRG-OS-000302')
      source_component = srg_component('EXSD-00', core_os)
      target_component = srg_component('EXTD-00', core_os)
      source = authored_row(source_component, '300002', derived_from: catalog_row)
      relocation = RequirementRelocation.create!(source_rule: source,
                                                 target_technology_token: 'EXTD')

      executor = described_class.new(relocation, target_component: target_component,
                                                 accepted_by: requester)
      allow(relocation).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(relocation))

      expect { executor.execute! }.to raise_error(ActiveRecord::RecordInvalid)

      expect(target_component.authored_srg_rules.count).to eq(0)
      expect(SrgRule.unscoped.find(source.id).deleted_at).to be_nil
      expect(relocation.reload.executed_at).to be_nil
    end
  end

  describe '#dry_run' do
    it 'previews the move with zero writes' do
      catalog_row = create(:srg_rule, security_requirements_guide: core_os, version: 'SRG-OS-000303')
      source_component = srg_component('EXSE-00', core_os)
      target_component = srg_component('EXTE-00', core_os)
      source = authored_row(source_component, '300003', derived_from: catalog_row)
      relocation = RequirementRelocation.create!(source_rule: source, target_technology_token: 'EXTE')

      preview = nil
      expect do
        preview = described_class.new(relocation, target_component: target_component).dry_run
      end.not_to(change { [SrgRule.unscoped.count, RequirementRelocation.count, source.reload.updated_at] })

      expect(preview[:valid]).to be true
      expect(preview[:source_displayed_name]).to eq('EXSE-00-300003')
      expect(preview[:would_create][:title]).to eq(source.title)
      expect(preview[:would_create][:derived_from_srg_rule_id]).to eq(catalog_row.id)
      expect(preview[:would_tombstone_source]).to be true
    end
  end

  describe 'validations' do
    it 'rejects an executed relocation, a stig target, a released target, the source component, and an undeclared source SRG' do
      catalog_row = create(:srg_rule, security_requirements_guide: core_os, version: 'SRG-OS-000304')
      source_component = srg_component('EXSF-00', core_os)
      source = authored_row(source_component, '300004', derived_from: catalog_row)

      tombstoned_source = authored_row(source_component, '300014')
      tombstoned_source.update!(deleted_at: Time.current)
      executed = RequirementRelocation.create!(source_rule: tombstoned_source,
                                               target_technology_token: 'X',
                                               executed_at: 1.day.ago)
      other_pending = RequirementRelocation.create!(source_rule: source, target_technology_token: 'Y')

      stig_target = create(:component, :skip_rules, project: project, prefix: 'EXST-00')
      app_only_target = srg_component('EXAP-00', core_app)
      released_target = srg_component('EXRL-00', core_os)
      released_target.update_column(:released, true)

      declined = RequirementRelocation.create!(source_rule: authored_row(source_component, '300024'),
                                               target_technology_token: 'X',
                                               declined_at: 1.day.ago, declined_by: requester,
                                               adjudication_rationale: 'Out of scope for this SRG.')

      expect(described_class.new(executed, target_component: srg_component('EXTF-00', core_os))
        .dry_run[:errors].join).to match(/no longer open/)
      expect(described_class.new(declined, target_component: srg_component('EXTG-00', core_os))
        .dry_run[:errors].join).to match(/no longer open/)
      expect(described_class.new(other_pending, target_component: stig_target)
        .dry_run[:errors].join).to match(/must be an SRG component/)
      expect(described_class.new(other_pending, target_component: released_target)
        .dry_run[:errors].join).to match(/released/)
      expect(described_class.new(other_pending, target_component: source_component)
        .dry_run[:errors].join).to match(/source component/)
      expect(described_class.new(other_pending, target_component: app_only_target)
        .dry_run[:errors].join).to match(/does not declare SRG-CORE-EXEC-OS as a source SRG/)

      expect do
        described_class.new(other_pending, target_component: stig_target, accepted_by: requester).execute!
      end.to raise_error(RelocationExecutor::ExecutionError, /SRG component/)
    end

    it 'refuses to land without an accepting actor' do
      source = authored_row(srg_component('EXSL-00', core_os), '300025')
      relocation = RequirementRelocation.create!(source_rule: source, target_technology_token: 'EXTL')

      expect do
        described_class.new(relocation, target_component: srg_component('EXTL-00', core_os)).execute!
      end.to raise_error(ArgumentError, /accepting actor/)
    end
  end

  describe 'one-directional invariant (model)' do
    it 'rejects stamping executed_at while the source row is still live' do
      source = authored_row(srg_component('EXSG-00', core_os), '300005')
      relocation = RequirementRelocation.create!(source_rule: source, target_technology_token: 'Z')

      relocation.executed_at = Time.current
      expect(relocation.save).to be false
      expect(relocation.errors[:executed_at].join).to match(/tombstoned/)
    end
  end

  describe 'tombstone semantics' do
    def executed_move(tag, reviewer)
      catalog_row = create(:srg_rule, security_requirements_guide: core_os,
                                      version: "SRG-OS-0003#{tag.ord}")
      source_component = srg_component("EXS#{tag}-00", core_os)
      target_component = srg_component("EXT#{tag}-00", core_os)
      source = authored_row(source_component, "3000#{tag.ord}", derived_from: catalog_row)
      source.update!(status: 'Applicable')
      review = create(:review, :comment, user: reviewer, rule: nil, commentable: source,
                                         comment: 'frozen comment', section: 'fixtext')
      relocation = RequirementRelocation.create!(source_rule: source, target_technology_token: 'T')
      result = described_class.new(relocation, target_component: target_component,
                                               accepted_by: reviewer).execute!
      [source_component, target_component, source, review, result]
    end

    it 'freezes reviews on the tombstone and keeps them out of active queries' do
      source_component, _target, source, review, = executed_move('A', requester)

      expect(Review.exists?(review.id)).to be true
      expect(BaseRule.live_for_components([source_component.id]).pluck(:id)).not_to include(source.id)
    end

    it 'removes the tombstone from completion math — the moved row leaves every bucket' do
      source_component, _target, _source, _review, = executed_move('B', requester)

      counts = source_component.status_counts
      expect(counts).to eq(not_yet_determined: 0, applicable: 0, not_applicable: 0)
      expect(source_component.requirements_count).to eq(0)
      expect(source_component.moved_out_count).to eq(1)
    end

    it 'never resurrects a tombstoned row through duplication' do
      source_component, _target, source, _review, = executed_move('C', requester)

      copy = source_component.duplicate(new_name: 'Post-move copy')
      copy.save!

      live_copy_rows = copy.authored_srg_rules.reload
      expect(live_copy_rows.map(&:rule_id)).not_to include(source.rule_id)
      expect(BaseRule.where(component_id: copy.id).where.not(deleted_at: nil).count).to eq(0)
    end
  end

  describe 'renumbering into the target sequence' do
    it 'lands the moved requirement on the next number in a POPULATED target — colliding source numbers included' do
      catalog_row = create(:srg_rule, security_requirements_guide: core_os, version: 'SRG-OS-000306')
      source_component = srg_component('EXSI-00', core_os)
      target_component = srg_component('EXTI-00', core_os)
      # The target already uses the source's number — the realistic case.
      authored_row(target_component, '000001')
      authored_row(target_component, '000002')
      source = authored_row(source_component, '000001', derived_from: catalog_row)
      relocation = RequirementRelocation.create!(source_rule: source, target_technology_token: 'EXTI')

      result = described_class.new(relocation, target_component: target_component,
                                               accepted_by: requester).execute!

      expect(result.target_rule.rule_id).to eq('000003')
      expect(target_component.authored_srg_rules.pluck(:rule_id))
        .to contain_exactly('000001', '000002', '000003')
    end

    it 'never reuses a tombstoned row number in the target' do
      source_component = srg_component('EXSJ-00', core_os)
      target_component = srg_component('EXTJ-00', core_os)
      tombstoned = authored_row(target_component, '000005')
      tombstoned.update!(deleted_at: Time.current)
      source = authored_row(source_component, '000001')
      relocation = RequirementRelocation.create!(source_rule: source, target_technology_token: 'EXTJ')

      result = described_class.new(relocation, target_component: target_component,
                                               accepted_by: requester).execute!

      expect(result.target_rule.rule_id).to eq('000006')
    end

    it 'previews the landed number in dry_run' do
      source_component = srg_component('EXSK-00', core_os)
      target_component = srg_component('EXTK-00', core_os)
      authored_row(target_component, '000007')
      source = authored_row(source_component, '000002')
      relocation = RequirementRelocation.create!(source_rule: source, target_technology_token: 'EXTK')

      preview = described_class.new(relocation, target_component: target_component).dry_run

      expect(preview[:would_create][:rule_id]).to eq('000008')
    end
  end

  describe 'orphan handling' do
    it 'nullifies target_rule_id with an audit note when the target is destroyed, and the sweep finds it' do
      catalog_row = create(:srg_rule, security_requirements_guide: core_os, version: 'SRG-OS-000305')
      source_component = srg_component('EXSH-00', core_os)
      target_component = srg_component('EXTH-00', core_os)
      source = authored_row(source_component, '300007', derived_from: catalog_row)
      relocation = RequirementRelocation.create!(source_rule: source, target_technology_token: 'W')
      result = described_class.new(relocation, target_component: target_component,
                                               accepted_by: requester).execute!

      result.target_rule.destroy!

      relocation.reload
      expect(relocation.target_rule_id).to be_nil
      expect(relocation.executed_at).to be_present
      expect(RequirementRelocation.executed_orphaned).to contain_exactly(relocation)
    end
  end
end
