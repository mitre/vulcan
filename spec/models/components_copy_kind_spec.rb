# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: component copy is ONE kind-aware path. Duplicating or
# overlaying an SRG component carries every live authored requirement as an
# SrgRule — content, status, and derived_from lineage intact, with the same
# lock/review-request resets STIG copies get. STIG duplicate behavior is
# unchanged. duplicate_reviews_and_history maps by requirement across both
# kinds, so authored requirements keep their discussion history on copy.
# ==========================================================================
RSpec.describe 'Component copy across document kinds' do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:other_project) { create(:project) }

  let_it_be(:core) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-COPYKIND', version: 'V1R1')
  end
  let_it_be(:core_rows) do
    %w[SRG-OS-000701 SRG-OS-000702].map do |version|
      create(:srg_rule, security_requirements_guide: core, version: version)
    end
  end

  def create_srg_source
    source = Component.create!(project: project, name: "SRG Source #{SecureRandom.hex(3)}",
                               prefix: 'COPY-00', title: 'Copy source', document_type: 'srg',
                               based_on: core)
    edited = source.authored_srg_rules.order(:rule_id).first
    edited.update!(status: 'Applicable', fixtext: 'Carried fixtext', audit_comment: 'copy setup')
    edited.checks.create!(system: 'C-copy', content: 'Carried check content')
    locked_row = source.authored_srg_rules.order(:rule_id).last
    locked_row.update!(locked: true, audit_comment: 'lock for copy setup')
    source
  end

  describe 'SRG duplicate' do
    it 'copies all live authored requirements as SrgRules with content, status, and lineage' do
      source = create_srg_source
      copy = source.duplicate(new_name: 'SRG Duplicate')
      copy.save!

      expect(copy.authored_srg_rules.count).to eq(2)
      expect(copy.authored_srg_rules.map(&:class).uniq).to eq([SrgRule])

      original = source.authored_srg_rules.order(:rule_id).first
      copied = copy.authored_srg_rules.find_by!(rule_id: original.rule_id)
      expect(copied.status).to eq('Applicable')
      expect(copied.fixtext).to eq('Carried fixtext')
      expect(copied.derived_from_srg_rule_id).to eq(original.derived_from_srg_rule_id)
      expect(copied.checks.map(&:content)).to include('Carried check content')
    end

    it 'resets locks and review requests on the copied requirements' do
      source = create_srg_source
      copy = source.duplicate(new_name: 'SRG Reset Check')
      copy.save!

      locked_original = source.authored_srg_rules.order(:rule_id).last
      copied = copy.authored_srg_rules.find_by!(rule_id: locked_original.rule_id)
      expect(locked_original.locked).to be(true)
      expect(copied.locked).to be(false)
      expect(copied.review_requestor_id).to be_nil
      expect(copied.locked_fields).to eq({})
    end
  end

  describe 'SRG duplicate soft-delete handling' do
    it 'copies only live authored requirements — tombstoned rows stay behind' do
      source = create_srg_source
      tombstoned = source.authored_srg_rules.order(:rule_id).last
      tombstoned.update_column(:deleted_at, Time.current)

      copy = source.duplicate(new_name: 'SRG Live Only')
      copy.save!

      expect(copy.authored_srg_rules.count).to eq(1)
      expect(copy.authored_srg_rules.pluck(:rule_id)).not_to include(tombstoned.rule_id)
    end
  end

  describe 'SRG overlay' do
    it 'carries requirements and links back to the source component' do
      source = create_srg_source
      # Overlays require a released source (existing model validation);
      # locking all requirements is the release precondition.
      source.authored_srg_rules.each { |r| r.update!(locked: true, audit_comment: 'release prep') }
      # Post-release state via the flow-intent flag — the seam the real
      # release machinery uses (a plain released update is rejected).
      source.via_release_flow = true
      source.update!(released: true)
      overlay = source.overlay(other_project.id)
      overlay.save!

      expect(overlay.component_id).to eq(source.id)
      expect(overlay.project_id).to eq(other_project.id)
      expect(overlay.authored_srg_rules.count).to eq(2)
      expect(overlay.authored_srg_rules.map(&:class).uniq).to eq([SrgRule])
      copied = overlay.authored_srg_rules.find_by!(fixtext: 'Carried fixtext')
      expect(copied.status).to eq('Applicable')
    end
  end

  describe 'STIG duplicate (regression pin)' do
    it 'still copies Rule rows with their nested records' do
      stig_source = create(:component, project: project)
      copy = stig_source.duplicate(new_name: 'STIG Duplicate Pin')
      copy.save!

      expect(copy.rules.count).to eq(stig_source.rules.count)
      expect(copy.authored_srg_rules.count).to eq(0)
      original = stig_source.rules.order(:rule_id).first
      copied = copy.rules.find_by!(rule_id: original.rule_id)
      expect(copied).to be_a(Rule)
      expect(copied.checks.count).to eq(original.checks.count)
      expect(copied.disa_rule_descriptions.count).to eq(original.disa_rule_descriptions.count)
    end

    it 'recreates satisfies relationships between the copied rules' do
      stig_source = create(:component, project: project)
      satisfier, satisfied = stig_source.rules.order(:rule_id).first(2)
      satisfier.satisfies << satisfied

      copy = stig_source.duplicate(new_name: 'STIG Satisfies Pin')
      copy.save!

      copied_satisfier = copy.rules.find_by!(rule_id: satisfier.rule_id)
      expect(copied_satisfier.satisfies.map(&:rule_id)).to eq([satisfied.rule_id])
      expect(copied_satisfier.satisfies.map(&:component_id).uniq).to eq([copy.id])
    end
  end

  describe 'duplicate_reviews_and_history across kinds' do
    include_context 'with auditing'

    it 'carries an authored requirement discussion onto the copy' do
      source = create_srg_source
      discussed = source.authored_srg_rules.order(:rule_id).first
      Review.create!(user: user, commentable: discussed, action: 'comment',
                     comment: 'Authored requirement discussion')

      copy = source.duplicate(new_name: 'SRG History Copy')
      copy.save!
      Component.without_auditing { copy.duplicate_reviews_and_history(source.id) }

      copied_row = copy.authored_srg_rules.find_by!(rule_id: discussed.rule_id)
      copied_reviews = Review.where(commentable_type: 'BaseRule', commentable_id: copied_row.id)
      expect(copied_reviews.pluck(:comment)).to include('Authored requirement discussion')
    end
  end
end
