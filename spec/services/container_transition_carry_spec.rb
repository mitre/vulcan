# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: The one-off Container transition carry is a PURE CARRIER.
# It consumes the merged plan json as the instruction set (which comments,
# which APP-core target, which research note) and reads the actual Review
# rows live from the source component. Carried comments keep who-said-what
# on the imported attribution columns, provenance on original_commentable_id,
# and their threading. Research context arrives as clearly-labeled
# "[Transition research]" comments, never attributed as team comments.
# The script writes NO requirement states — every target row remains
# Not Yet Determined; all state-setting belongs to the authoring pass.
# Re-runs are refused. Rows without a target carry nothing and are reported.
# ==========================================================================
RSpec.describe ContainerTransitionCarry do
  let_it_be(:app_core) { create(:security_requirements_guide, :core, :skip_rules) }
  let_it_be(:catalog_row_a) do
    create(:srg_rule, security_requirements_guide: app_core, version: 'SRG-APP-000005',
                      title: 'The application must retain the device lock')
  end
  let_it_be(:catalog_row_b) do
    create(:srg_rule, security_requirements_guide: app_core, version: 'SRG-APP-000125',
                      title: 'The application must back up audit records')
  end

  let_it_be(:target) do
    create(:component, :skip_rules, document_type: 'srg', based_on: app_core,
                                    prefix: 'CTRR-00', name: 'Container redo target').tap do |c|
      RequirementImportService.new(c).import_parent!(app_core)
    end
  end

  let_it_be(:source) { create(:component, :skip_rules, name: 'Container SRG source') }
  let_it_be(:source_rule_a) { create(:rule, component: source, rule_id: '001028') }
  let_it_be(:source_rule_b) { create(:rule, component: source, rule_id: '001215') }
  let_it_be(:commenter) { create(:user, name: 'QA Reviewer') }
  let_it_be(:replier) { create(:user, name: 'STIG Author') }

  let_it_be(:na_comment) do
    create(:review, :comment, user: commenter, rule: source_rule_a,
                              comment: 'A container should not be maintaining local interactive users.')
  end
  let_it_be(:na_reply) do
    create(:review, :comment, user: replier, rule: source_rule_a,
                              responding_to_review_id: na_comment.id,
                              comment: 'This requirement is addressed by CNTR-00-000030.')
  end
  let_it_be(:noise_comment) do
    create(:review, :comment, user: replier, rule: source_rule_a, comment: 'test')
  end

  def plan_hash
    {
      rows: [
        { source: { rule_db_id: source_rule_a.id, displayed: 'CNTR-00-001028' },
          target: { app_core_requirement: 'SRG-APP-000005' },
          carry_comment_ids: [na_comment.id],
          research_note: nil },
        { source: { rule_db_id: source_rule_b.id, displayed: 'CNTR-00-001215' },
          target: { app_core_requirement: 'SRG-APP-000125' },
          carry_comment_ids: [],
          research_note: 'Audit-analysis capability is covered nowhere in the container stack — ' \
                         'the platform document stops at generation; the obligation lands on the ' \
                         'enterprise audit service.' },
        { source: { rule_db_id: 999_999, displayed: 'CNTR-00-000010' },
          target: { app_core_requirement: nil },
          carry_comment_ids: [],
          research_note: nil,
          skip_reason: 'Container-authored requirement; re-authored under the APP core' },
        { source: { rule_db_id: 999_998, displayed: 'CNTR-00-001999' },
          target: { app_core_requirement: 'SRG-APP-999999' },
          carry_comment_ids: [],
          research_note: nil }
      ]
    }
  end

  let(:plan_file) do
    file = Tempfile.new(['carry-plan', '.json'])
    file.write(JSON.generate(plan_hash))
    file.close
    file
  end

  after { plan_file.unlink }

  def target_row(version)
    target.authored_srg_rules.reload.find { |r| r.derived_from&.version == version }
  end

  def run_carry
    described_class.new(plan_path: plan_file.path, target_component: target).call
  end

  describe '#call' do
    it 'carries a top-level comment with attribution and provenance, leaving the row Not Yet Determined' do
      run_carry

      row = target_row('SRG-APP-000005')
      carried = Review.where(rule_id: row.id, action: 'comment')
                      .find_by(comment: 'A container should not be maintaining local interactive users.')
      expect(carried).to be_present
      expect(carried.user_id).to be_nil
      expect(carried.commenter_imported_name).to eq('QA Reviewer')
      expect(carried.commenter_imported_email).to eq(commenter.email)
      expect(carried.original_commentable_id).to eq(source_rule_a.id)
      expect(carried.section).to eq(na_comment.section)
      expect(row.reload.status).to eq('Not Yet Determined')
    end

    it 'preserves threading — the reply lands under the carried parent on the same row' do
      run_carry

      row_id = target_row('SRG-APP-000005').id
      parent = Review.where(rule_id: row_id)
                     .find_by(comment: 'A container should not be maintaining local interactive users.')
      reply = Review.where(rule_id: row_id)
                    .find_by(comment: 'This requirement is addressed by CNTR-00-000030.')
      expect(reply).to be_present
      expect(reply.responding_to_review_id).to eq(parent.id)
      expect(reply.commenter_imported_name).to eq('STIG Author')
    end

    it 'carries replies at ANY depth — a reply to a reply lands on the target thread' do
      grandchild = create(:review, :comment, user: replier, rule: source_rule_a,
                                             responding_to_review_id: na_reply.id,
                                             comment: 'And CNTR-00-000030 is satisfied by the platform.')

      run_carry

      row_id = target_row('SRG-APP-000005').id
      carried_reply = Review.where(rule_id: row_id)
                            .find_by(comment: 'This requirement is addressed by CNTR-00-000030.')
      carried_grandchild = Review.where(rule_id: row_id)
                                 .find_by(comment: grandchild.comment)
      expect(carried_grandchild).to be_present
      expect(carried_grandchild.responding_to_review_id).to eq(carried_reply.id)
    end

    it 'posts the research note as a clearly-labeled comment, distinct from carried team comments' do
      run_carry

      row = target_row('SRG-APP-000125')
      note = Review.where(rule_id: row.id, action: 'comment').find_by('comment LIKE ?', '[Transition research]%')
      expect(note).to be_present
      expect(note.comment).to include('enterprise audit service')
      expect(note.commenter_imported_name).to eq(described_class::RESEARCH_AUTHOR)
      expect(note.original_commentable_id).to be_nil
      expect(note.user_id).to be_nil
    end

    it 'writes no requirement states — every target row remains Not Yet Determined and unlocked' do
      run_carry

      expect(target.authored_srg_rules.reload.pluck(:status).uniq).to eq(['Not Yet Determined'])
      expect(target.authored_srg_rules.pluck(:locked).uniq).to eq([false])
    end

    it 'carries only the planned comment ids — unplanned (noise) comments never cross' do
      run_carry

      expect(Review.where(rule_id: target.requirements.select(:id), comment: 'test')).to be_empty
    end

    it 'refuses a second run without duplicating anything' do
      run_carry
      before_count = Review.count

      expect { run_carry }.to raise_error(ContainerTransitionCarry::AlreadyCarried)
      expect(Review.count).to eq(before_count)
    end

    it 'reports carried, research-noted, and skipped rows with their targets and reasons' do
      report = run_carry

      expect(report.carried).to contain_exactly(
        { displayed: 'CNTR-00-001028', target: 'SRG-APP-000005', comments: 2 }
      )
      expect(report.research_noted).to contain_exactly(
        { displayed: 'CNTR-00-001215', target: 'SRG-APP-000125' }
      )
      expect(report.skipped).to contain_exactly(
        { displayed: 'CNTR-00-000010', target: nil,
          reason: 'Container-authored requirement; re-authored under the APP core' },
        { displayed: 'CNTR-00-001999', target: 'SRG-APP-999999',
          reason: 'target row SRG-APP-999999 not found on the component' }
      )
    end

    it 'raises when the target component is not an srg-kind component' do
      stig_target = create(:component, :skip_rules)
      expect { described_class.new(plan_path: plan_file.path, target_component: stig_target).call }
        .to raise_error(ArgumentError, /srg/)
    end
  end
end
