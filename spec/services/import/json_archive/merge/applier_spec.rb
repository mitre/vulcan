# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::JsonArchive::Merge::Applier, type: :service do
  # All applier specs short-circuit SnapshotManager: it's tested in its own
  # spec, and exercising it here would write real zips to the default
  # storage path. Override locally in specs that assert on snapshot paths.
  before do
    allow(Import::JsonArchive::Merge::SnapshotManager)
      .to receive(:create_snapshot).and_return('/tmp/applier_spec_default_snapshot.zip')
  end

  let(:component) { create(:component, :closed_comment_phase) }
  let(:strategy) { Import::JsonArchive::Merge::Strategy.new }
  let(:manifest) { { 'backup_format_version' => '1.1' } }
  let(:archive_bytes) { 'fake archive bytes' }

  # A no-op plan over an unchanged component — applier should run through
  # the full lifecycle without writing any entity changes.
  let(:plan) do
    Import::JsonArchive::Merge::Analyzer.new(
      merge_input: Import::JsonArchive::Merge::MergeInput.from_json_archive(build_backup_hash(component), manifest: manifest),
      component: component,
      strategy: strategy,
      manifest: manifest
    ).call
  end

  describe '#call (lifecycle on a no-op plan)' do
    subject(:result) do
      described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
    end

    it 'returns a MergeResult' do
      expect(result).to be_a(Import::JsonArchive::Merge::MergeResult)
    end

    it 'creates exactly one ComponentSyncEvent with status applied' do
      expect { result }.to change(ComponentSyncEvent, :count).by(1)
      expect(ComponentSyncEvent.last.status).to eq('applied')
    end

    it 'records the merge source and inbound direction' do
      result
      event = ComponentSyncEvent.last
      expect(event.direction).to eq('inbound')
      expect(event.source).to eq('theirs')
    end

    it 'generates a unique sync_id (UUID)' do
      result
      event = ComponentSyncEvent.last
      expect(event.sync_id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it 'persists the MergePlan resolution_log on the sync event' do
      plan.add_resolution_log_entry(entry: { 'note' => 'no-op' })
      result
      event = ComponentSyncEvent.last
      expect(event.resolution_log_json).to be_an(Array)
      expect(event.resolution_log_json.first).to include('note' => 'no-op')
    end

    it 'attaches the sync event to the result via #plan or accessor' do
      expect(result.plan).to eq(plan)
    end
  end

  describe '#call (transaction safety)' do
    # The applier requests isolation: :serializable only when invoked
    # outside an existing transaction (production controller / rake
    # path). Inside a wrapping transaction — as here under transactional
    # fixtures — it joins without changing isolation, so the call must
    # NOT raise TransactionIsolationError.
    it 'joins an existing transaction when one is already open (no TransactionIsolationError)' do
      expect(ActiveRecord::Base.connection.transaction_open?).to be(true) # sanity: we ARE in one
      r = described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      expect(r.success?).to be(true)
    end

    it 'rescues SerializationFailure from apply_all and surfaces "component modified during merge"' do
      applier = described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes)
      allow(applier).to receive(:apply_all).and_raise(ActiveRecord::SerializationFailure.new('serial'))

      r = applier.call

      expect(r.success?).to be(false)
      expect(r.errors.join).to include('component modified during merge')
    end
  end

  describe '#call (failure marks event)' do
    it 'sets sync event status to failed on apply_all error' do
      applier = described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes)
      allow(applier).to receive(:apply_all).and_raise(ActiveRecord::StatementInvalid.new('boom'))

      applier.call

      expect(ComponentSyncEvent.last.status).to eq('failed')
    end
  end

  describe '#call (failure_diagnostics_json v2-480.36)' do
    it 'populates failure_diagnostics on a StandardError apply failure' do
      applier = described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes)
      allow(applier).to receive(:apply_all).and_raise(ActiveRecord::StatementInvalid.new('boom'))

      applier.call

      diag = ComponentSyncEvent.last.failure_diagnostics_json
      expect(diag).to be_a(Hash)
      expect(diag['exception_class']).to eq('ActiveRecord::StatementInvalid')
      expect(diag['exception_message']).to include('boom')
      expect(diag['structured_errors']).to be_an(Array).and(be_present)
      expect(diag['structured_errors'].first).to include('step' => 'apply')
    end

    it 'populates failure_diagnostics on SerializationFailure' do
      applier = described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes)
      allow(applier).to receive(:apply_all).and_raise(ActiveRecord::SerializationFailure.new('serial'))

      applier.call

      diag = ComponentSyncEvent.last.failure_diagnostics_json
      expect(diag['exception_class']).to eq('ActiveRecord::SerializationFailure')
      expect(diag['structured_errors'].first['message']).to include('component modified during merge')
    end

    it 'populates failure_diagnostics on PreconditionError (open comment phase)' do
      open_component = create(:component, :open_comment_period)
      open_plan = Import::JsonArchive::Merge::Analyzer.new(
        merge_input: Import::JsonArchive::Merge::MergeInput.from_json_archive(build_backup_hash(open_component), manifest: manifest),
        component: open_component, strategy: strategy, manifest: manifest
      ).call

      described_class.new(merge_plan: open_plan, component: open_component, source: 'theirs', archive_bytes: archive_bytes).call

      diag = ComponentSyncEvent.last.failure_diagnostics_json
      expect(diag['exception_class']).to eq('Import::JsonArchive::Merge::PreconditionError')
      expect(diag['exception_message']).to match(/comment_phase/i)
      expect(diag['structured_errors'].first['step']).to eq('precondition')
    end

    it 'leaves failure_diagnostics nil on a successful apply' do
      described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      expect(ComponentSyncEvent.last.failure_diagnostics_json).to be_nil
    end
  end

  describe '#call (pre-merge snapshot + archive hash)' do
    let(:tmp_snapshot_path) { Tempfile.new(['snapshot', '.zip']).path }

    before do
      allow(Import::JsonArchive::Merge::SnapshotManager)
        .to receive(:create_snapshot).and_return(tmp_snapshot_path)
    end

    it 'creates a snapshot via SnapshotManager and records the path on the sync event' do
      expect(Import::JsonArchive::Merge::SnapshotManager).to receive(:create_snapshot).with(component)

      described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(ComponentSyncEvent.last.snapshot_path).to eq(tmp_snapshot_path)
    end

    it 'stores SHA-256 of the archive bytes on the sync event' do
      described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      event = ComponentSyncEvent.last
      expect(event.archive_hash).to eq(Digest::SHA256.hexdigest(archive_bytes))
    end

    it 'leaves archive_hash nil when archive_bytes is nil (caller did not provide)' do
      described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: nil).call

      expect(ComponentSyncEvent.last.archive_hash).to be_nil
    end

    it 'calls SnapshotManager.rotate_snapshots after a successful apply (v2-480.38)' do
      expect(Import::JsonArchive::Merge::SnapshotManager).to receive(:rotate_snapshots).with(component)
      described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
    end

    it 'does NOT call SnapshotManager.rotate_snapshots on a failed apply (v2-480.38)' do
      applier = described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes)
      allow(applier).to receive(:apply_all).and_raise(StandardError, 'spec abort')
      expect(Import::JsonArchive::Merge::SnapshotManager).not_to receive(:rotate_snapshots)
      applier.call
    end
  end

  describe '#call (applies rule auto-merged changes)' do
    # Build a plan with one auto_theirs field change so we can observe
    # the applier write to the DB + log a merge_operations row.
    let(:target_rule) { component.rules.first }
    let(:auto_plan) do
      p = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id,
        strategy: strategy,
        manifest: manifest
      )
      change = Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
        field: 'fixtext', from: target_rule.fixtext, to: 'THEIRS fixtext',
        resolution: :auto_theirs, locked: false, reason: 'Strategy resolved to :theirs'
      )
      p.add_field_changes(target_rule.rule_id, [change])
      p
    end

    it 'persists the field change on the rule' do
      described_class.new(merge_plan: auto_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(target_rule.reload.fixtext).to eq('THEIRS fixtext')
    end

    it 'writes one MergeOperation row per applied field with before/after captured' do
      expect do
        described_class.new(merge_plan: auto_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change(MergeOperation, :count).by(1)

      op = MergeOperation.last
      expect(op.entity_type).to eq('rule')
      expect(op.entity_key).to eq(target_rule.rule_id)
      expect(op.field_name).to eq('fixtext')
      expect(op.new_value).to eq('THEIRS fixtext')
      expect(op.operation).to eq('update')
      expect(op.source).to eq('theirs')
    end

    it ':auto_ours uses the from value (keeps ours), still logs the operation' do
      auto_ours_plan = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      auto_ours_plan.add_field_changes(target_rule.rule_id, [
                                         Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
                                           field: 'fixtext', from: 'OURS fixtext keep', to: 'THEIRS fixtext drop',
                                           resolution: :auto_ours, locked: false, reason: ''
                                         )
                                       ])

      described_class.new(merge_plan: auto_ours_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      # auto_ours = keep ours; the rule's current value stays. No DB change.
      expect(target_rule.reload.fixtext).to eq(target_rule.fixtext)
      op = MergeOperation.last
      expect(op.source).to eq('ours')
    end

    it 'recalculates the components.rules_count counter cache after rule writes' do
      original_count = component.rules.where(deleted_at: nil).count
      component.update_columns(rules_count: 9999) # -- corrupt the cache to verify recalc

      described_class.new(merge_plan: auto_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(component.reload.rules_count).to eq(original_count)
    end
  end

  describe '#call (routes nested-association FieldChanges)' do
    let(:target_rule) { component.rules.first }
    let(:check) { target_rule.checks.first }
    let(:disa) { target_rule.disa_rule_descriptions.first }

    def field_change(field:, from:, to:, target_association:, target_identity: nil)
      Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
        field: field, from: from, to: to,
        resolution: :auto_theirs, locked: false,
        reason: 'spec', target_association: target_association,
        target_identity: target_identity
      )
    end

    it 'Check#content lands on the Check row, NOT on the Rule' do
      plan_with_check = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      plan_with_check.add_field_changes(target_rule.rule_id, [
                                          field_change(
                                            field: 'content', from: check.content, to: 'THEIRS check content',
                                            target_association: :checks,
                                            target_identity: { 'system' => check.system }
                                          )
                                        ])

      described_class.new(merge_plan: plan_with_check, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(check.reload.content).to eq('THEIRS check content')
      expect(MergeOperation.where(entity_type: 'checks', operation: 'update').last.entity_id).to eq(check.id)
    end

    it 'DisaRuleDescription#vuln_discussion lands on the disa_rule_descriptions row' do
      plan_with_disa = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      plan_with_disa.add_field_changes(target_rule.rule_id, [
                                         field_change(
                                           field: 'vuln_discussion',
                                           from: disa.vuln_discussion, to: 'THEIRS vuln discussion',
                                           target_association: :disa_rule_descriptions, target_identity: nil
                                         )
                                       ])

      described_class.new(merge_plan: plan_with_disa, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(disa.reload.vuln_discussion).to eq('THEIRS vuln discussion')
      expect(MergeOperation.where(entity_type: 'disa_rule_descriptions', operation: 'update').last.entity_id).to eq(disa.id)
    end

    it 'severity_override_guidance under DISA Metadata locked section is skipped (record_skipped_conflicts)' do
      target_rule.update!(locked_fields: { 'DISA Metadata' => true })
      locked_change = Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
        field: 'severity_override_guidance',
        from: disa.severity_override_guidance, to: 'THEIRS sev override',
        resolution: :locked_conflict, locked: true, reason: 'locked',
        target_association: :disa_rule_descriptions, target_identity: nil
      )
      locked_plan = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      locked_plan.add_field_changes(target_rule.rule_id, [locked_change])

      described_class.new(merge_plan: locked_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(disa.reload.severity_override_guidance).not_to eq('THEIRS sev override')
      skip = MergeOperation.where(entity_type: 'rule', operation: 'skip', field_name: 'severity_override_guidance').last
      expect(skip).not_to be_nil
    end
  end

  describe '#call (skips conflict / locked_conflict)' do
    let(:target_rule) { component.rules.first }
    let(:conflict_plan) do
      p = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      p.add_field_changes(target_rule.rule_id, [
                            Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
                              field: 'fixtext', from: 'OURS', to: 'THEIRS',
                              resolution: :conflict, locked: false, reason: 'Strategy default'
                            ),
                            Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
                              field: 'title', from: 'ours title', to: 'theirs title',
                              resolution: :locked_conflict, locked: true, reason: "section 'Title' locked"
                            )
                          ])
      p
    end

    it 'does NOT write conflicted fields to the rule' do
      original_fixtext = target_rule.fixtext
      original_title = target_rule.title

      described_class.new(merge_plan: conflict_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      target_rule.reload
      expect(target_rule.fixtext).to eq(original_fixtext)
      expect(target_rule.title).to eq(original_title)
    end

    it 'records a merge_operations row with operation=skip for every conflict' do
      expect do
        described_class.new(merge_plan: conflict_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change(MergeOperation.where(operation: 'skip'), :count).by(2)

      skipped_fields = MergeOperation.where(operation: 'skip').pluck(:field_name).sort
      expect(skipped_fields).to eq(%w[fixtext title])
    end

    it 'tags the skip source as conflict_resolved' do
      described_class.new(merge_plan: conflict_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      sources = MergeOperation.where(operation: 'skip').pluck(:source).uniq
      expect(sources).to eq(['conflict_resolved'])
    end
  end

  describe '#call (imports only_theirs reviews)' do
    let(:target_rule) { component.rules.first }
    let(:new_review_hash) do
      {
        'external_id' => 42,
        'rule_id' => target_rule.rule_id,
        'action' => 'comment',
        'section' => 'check_content',
        'comment' => 'NEW from theirs',
        'created_at' => Time.zone.local(2026, 6, 7, 12, 0).iso8601(6),
        'user_email' => 'someone@example.com',
        'user_name' => 'Someone Example'
      }
    end
    let(:review_plan) do
      p = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      p.add_review_partition(matched: [], only_ours: [], only_theirs: [new_review_hash])
      p
    end

    before do
      # ReviewBuilder needs a user matching user_email or it'll skip with a warning
      create(:user, email: 'someone@example.com', name: 'Someone Example')
      # And a project membership so the import passes commenter validation
      Membership.create!(user: User.find_by(email: 'someone@example.com'), membership: component.project, role: 'viewer')
    end

    it 'creates the new review in the DB scoped to the matched rule' do
      expect do
        described_class.new(merge_plan: review_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change { target_rule.reviews.count }.by(1)

      review = target_rule.reviews.order(:created_at).last
      expect(review.comment).to eq('NEW from theirs')
    end

    it 'records a merge_operations row with operation=insert for each new review' do
      expect do
        described_class.new(merge_plan: review_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change(MergeOperation.where(entity_type: 'review', operation: 'insert'), :count).by(1)

      op = MergeOperation.where(entity_type: 'review', operation: 'insert').last
      expect(op.entity_key).to eq('42') # external_id from archive
      expect(op.source).to eq('theirs')
    end

    it 'stamps entity_id with the actual inserted Review.id (not zero)' do
      described_class.new(merge_plan: review_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      inserted = target_rule.reviews.order(:created_at).last
      op = MergeOperation.where(entity_type: 'review', operation: 'insert').last
      expect(op.entity_id).to eq(inserted.id)
      expect(op.entity_id).to be > 0
    end

    it 'skips merge_operations rows for reviews ReviewBuilder dropped (missing rule_id)' do
      # One landing review + one with an unresolvable rule_id (ReviewBuilder skips it)
      skipped_review = new_review_hash.merge(
        'external_id' => 99, 'rule_id' => 'NONEXISTENT-V-9999',
        'comment' => 'should be skipped'
      )
      mixed_plan = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      mixed_plan.add_review_partition(matched: [], only_ours: [], only_theirs: [new_review_hash, skipped_review])

      expect do
        described_class.new(merge_plan: mixed_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change(MergeOperation.where(entity_type: 'review', operation: 'insert'), :count).by(1)

      ops = MergeOperation.where(entity_type: 'review', operation: 'insert')
      expect(ops.pluck(:entity_key)).to contain_exactly('42') # not '99' — that one was skipped
      expect(ops.pluck(:entity_id)).to all(be > 0)
    end

    it 'is a no-op when only_theirs is empty' do
      empty_plan = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      empty_plan.add_review_partition(matched: [], only_ours: [], only_theirs: [])

      expect do
        described_class.new(merge_plan: empty_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.not_to(change(Review, :count))
    end
  end

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  describe '#call (updates matched review fields per Strategy)' do
    let(:target_rule) { component.rules.first }
    let(:existing_review) do
      create(:review, rule: target_rule, user: create(:user, email: 'commenter@example.com'),
                      action: 'comment', section: 'check_content', comment: 'existing comment',
                      triage_status: 'concur')
    end
    # Strategy override so triage_status edits actually take effect — by
    # default Strategy says ours wins for triage state.
    let(:theirs_wins) do
      Import::JsonArchive::Merge::Strategy.new(
        overrides: { review: { 'triage_status' => :theirs } }
      )
    end
    let(:ours_hash) do
      {
        'external_id' => existing_review.id, 'rule_id' => target_rule.rule_id,
        'comment' => 'existing comment', 'created_at' => existing_review.created_at.iso8601(6),
        'triage_status' => 'concur'
      }
    end
    let(:theirs_hash) { ours_hash.merge('triage_status' => 'non_concur') }
    let(:matched_plan) do
      p = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: theirs_wins, manifest: manifest
      )
      p.add_review_partition(matched: [{ ours: ours_hash, theirs: theirs_hash }], only_ours: [], only_theirs: [])
      p
    end

    before { existing_review } # let-bang trick: realize the review before the applier runs

    it 'updates the field on the matched review' do
      described_class.new(merge_plan: matched_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(existing_review.reload.triage_status).to eq('non_concur')
    end

    it 'records a merge_operations row with operation=update for the changed field' do
      expect do
        described_class.new(merge_plan: matched_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change(MergeOperation.where(entity_type: 'review', operation: 'update'), :count).by(1)

      op = MergeOperation.where(entity_type: 'review', operation: 'update').last
      expect(op.entity_key).to eq(existing_review.id.to_s)
      expect(op.field_name).to eq('triage_status')
      expect(op.old_value).to eq('concur')
      expect(op.new_value).to eq('non_concur')
      expect(op.source).to eq('theirs')
    end

    it 'does NOT update when Strategy default (review triage_status → ours) is in effect' do
      ours_default_plan = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      ours_default_plan.add_review_partition(matched: [{ ours: ours_hash, theirs: theirs_hash }], only_ours: [], only_theirs: [])

      described_class.new(merge_plan: ours_default_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(existing_review.reload.triage_status).to eq('concur') # unchanged
    end

    it 'calls repair_missing_commentable! after updates as a defensive safety net' do
      expect(Review).to receive(:repair_missing_commentable!).at_least(:once).and_call_original

      described_class.new(merge_plan: matched_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
    end

    context 'when theirs updates addressed_by_rule_id (bigint FK via archive rule_id string)' do
      # addressed_by_rule_id is only allowed when triage_status='addressed_by' —
      # Review#clear_stale_foreign_keys nils it under any other status. Existing
      # review is set up in that addressed_by state pointing at NO rule; theirs
      # supplies the archive rule_id string of the rule we want to address.
      let(:addressed_rule) { component.rules.second }
      let(:prior_addressed_rule) { component.rules.third }
      let(:remap_strategy) do
        Import::JsonArchive::Merge::Strategy.new(
          overrides: { review: { 'addressed_by_rule_id' => :theirs } }
        )
      end
      let(:addressed_review) do
        create(:review, rule: target_rule, user: create(:user, email: 'addr@example.com'),
                        action: 'comment', section: 'check_content',
                        comment: 'addressed_by sample',
                        triage_status: 'addressed_by',
                        addressed_by_rule_id: prior_addressed_rule.id)
      end
      let(:addressed_ours) do
        {
          'external_id' => addressed_review.id, 'rule_id' => target_rule.rule_id,
          'comment' => addressed_review.comment,
          'created_at' => addressed_review.created_at.iso8601(6),
          'triage_status' => 'addressed_by',
          'addressed_by_rule_id' => prior_addressed_rule.id
        }
      end
      let(:theirs_with_archive_string) { addressed_ours.merge('addressed_by_rule_id' => addressed_rule.rule_id) }
      let(:remap_plan) do
        p = Import::JsonArchive::Merge::MergePlan.new(
          component_id: component.id, strategy: remap_strategy, manifest: manifest
        )
        p.add_review_partition(matched: [{ ours: addressed_ours, theirs: theirs_with_archive_string }],
                               only_ours: [], only_theirs: [])
        p
      end

      before { addressed_review } # realize before applier runs

      it 'remaps the archive rule_id string to the live BaseRule.id before assign_attributes' do
        described_class.new(merge_plan: remap_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

        expect(addressed_review.reload.addressed_by_rule_id).to eq(addressed_rule.id)
      end

      it 'warns and skips when the archive rule_id is not present on the receiving component' do
        bad_theirs = addressed_ours.merge('addressed_by_rule_id' => 'V-NONEXISTENT-1')
        bad_plan = Import::JsonArchive::Merge::MergePlan.new(
          component_id: component.id, strategy: remap_strategy, manifest: manifest
        )
        bad_plan.add_review_partition(matched: [{ ours: addressed_ours, theirs: bad_theirs }],
                                      only_ours: [], only_theirs: [])

        result = described_class.new(merge_plan: bad_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

        expect(result.warnings.join).to match(/addressed_by_rule_id .* not present/i)
        expect(addressed_review.reload.addressed_by_rule_id).to eq(prior_addressed_rule.id) # unchanged
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  describe '#call (applies only_theirs rules)' do
    let(:srg) { component.security_requirements_guide }
    let(:new_rule_hash) do
      existing = component.rules.first
      {
        'rule_id' => 'V-99999', 'title' => 'Brand new from theirs',
        'srg_rule_version' => existing.srg_rule&.version,
        'status' => 'Applicable - Configurable', 'rule_severity' => 'medium',
        'fixtext' => 'Set X to Y.', 'vendor_comments' => '',
        'locked' => false, 'locked_fields' => {}
      }
    end
    let(:new_rule_plan) do
      p = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      p.add_rule_partition(matched: [], only_ours: [], only_theirs: [new_rule_hash])
      p
    end

    it 'inserts the new rule via RuleBuilder' do
      expect do
        described_class.new(merge_plan: new_rule_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change { component.rules.where(rule_id: 'V-99999').count }.from(0).to(1)

      inserted = component.rules.find_by(rule_id: 'V-99999')
      expect(inserted.title).to eq('Brand new from theirs')
    end

    it 'writes a MergeOperation insert row tagged with the new Rule.id' do
      expect do
        described_class.new(merge_plan: new_rule_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change(MergeOperation.where(entity_type: 'rule', operation: 'insert'), :count).by(1)

      op = MergeOperation.where(entity_type: 'rule', operation: 'insert').last
      inserted = component.rules.find_by(rule_id: 'V-99999')
      expect(op.entity_id).to eq(inserted.id)
      expect(op.entity_key).to eq('V-99999')
      expect(op.source).to eq('theirs')
    end

    it 'refreshes rule_id_map so a satisfaction referencing the new rule resolves correctly' do
      anchor = component.rules.first
      sat_hash = { 'rule_id' => anchor.rule_id, 'satisfied_by_rule_id' => 'V-99999' }
      new_rule_plan.add_satisfaction_partition(matched: [], only_ours: [], only_theirs: [sat_hash])

      described_class.new(merge_plan: new_rule_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      newly_inserted = component.rules.find_by(rule_id: 'V-99999')
      expect(RuleSatisfaction.where(rule_id: anchor.id, satisfied_by_rule_id: newly_inserted.id)).to exist
    end
  end

  describe '#call (applies only_theirs satisfactions)' do
    let(:satisfier) { component.rules.first }
    let(:satisfied) { component.rules.second }

    let(:satisfaction_hash) do
      { 'rule_id' => satisfied.rule_id, 'satisfied_by_rule_id' => satisfier.rule_id }
    end
    let(:satisfaction_plan) do
      p = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      p.add_satisfaction_partition(matched: [], only_ours: [], only_theirs: [satisfaction_hash])
      p
    end

    it 'inserts new satisfaction row resolving rule_id strings to DB ids' do
      expect do
        described_class.new(merge_plan: satisfaction_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change(RuleSatisfaction, :count).by(1)

      # rule_satisfactions has no PK; query by composite key.
      sat = RuleSatisfaction.find_by(rule_id: satisfied.id, satisfied_by_rule_id: satisfier.id)
      expect(sat).not_to be_nil
    end

    it 'is idempotent: re-applying an existing satisfaction does not raise or double-insert' do
      RuleSatisfaction.create!(rule_id: satisfied.id, satisfied_by_rule_id: satisfier.id)

      expect do
        described_class.new(merge_plan: satisfaction_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.not_to(change(RuleSatisfaction, :count))
    end

    it 'records a merge_operations row with operation=insert per applied satisfaction' do
      expect do
        described_class.new(merge_plan: satisfaction_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change(MergeOperation.where(entity_type: 'satisfaction', operation: 'insert'), :count).by(1)

      op = MergeOperation.where(entity_type: 'satisfaction').last
      expect(op.entity_key).to eq("#{satisfied.rule_id}::#{satisfier.rule_id}")
      expect(op.source).to eq('theirs')
    end

    it 'skips with a warning when a referenced rule_id is unknown on the receiving side' do
      bad_hash = { 'rule_id' => 'V-DOES-NOT-EXIST', 'satisfied_by_rule_id' => satisfier.rule_id }
      bad_plan = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      bad_plan.add_satisfaction_partition(matched: [], only_ours: [], only_theirs: [bad_hash])

      result = described_class.new(merge_plan: bad_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(result.warnings.join).to match(/V-DOES-NOT-EXIST/i)
      expect(RuleSatisfaction.count).to eq(0)
    end
  end

  describe '#call (applies memberships)' do
    let(:known_user) { create(:user, email: 'newcomer@example.com', name: 'New Comer') }
    let(:new_membership_hash) { { 'email' => known_user.email, 'name' => known_user.name, 'role' => 'admin' } }
    let(:unknown_membership_hash) { { 'email' => 'ghost@nowhere.local', 'name' => 'Ghost', 'role' => 'admin' } }

    let(:membership_plan) do
      p = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      p.add_membership_partition(matched: [], only_ours: [], only_theirs: [new_membership_hash])
      p
    end

    before { known_user } # realize

    it 'adds a project membership at viewer (NEVER auto-escalates the role from the archive)' do
      expect do
        described_class.new(merge_plan: membership_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change(Membership, :count).by(1)

      m = Membership.find_by(user: known_user, membership: component.project)
      expect(m.role).to eq('viewer') # not 'admin' from the archive
    end

    it 'records a merge_operations row with operation=insert for added membership' do
      expect do
        described_class.new(merge_plan: membership_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change(MergeOperation.where(entity_type: 'membership', operation: 'insert'), :count).by(1)

      op = MergeOperation.where(entity_type: 'membership').last
      expect(op.entity_key).to eq(known_user.email)
      expect(op.source).to eq('theirs')
    end

    it 'skips unknown users with a warning rather than creating ghost rows' do
      unknown_plan = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      unknown_plan.add_membership_partition(matched: [], only_ours: [], only_theirs: [unknown_membership_hash])

      result = described_class.new(merge_plan: unknown_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(result.warnings.join).to match(/ghost@nowhere\.local/)
      expect(Membership.where(membership: component.project).count).to eq(0)
    end

    it 'matched memberships are not re-inserted' do
      Membership.create!(user: known_user, membership: component.project, role: 'viewer')
      matched_plan = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      matched_plan.add_membership_partition(matched: [new_membership_hash], only_ours: [], only_theirs: [])

      expect do
        described_class.new(merge_plan: matched_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.not_to(change(Membership, :count))
    end
  end

  describe '#call (quarantines invalid records)' do
    let(:known_user) { create(:user, email: 'q@example.com', name: 'Quaranteen') }
    let(:m_hash) { { 'email' => known_user.email, 'name' => known_user.name, 'role' => 'viewer' } }
    let(:bad_plan) do
      p = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      p.add_membership_partition(matched: [], only_ours: [], only_theirs: [m_hash])
      p
    end

    before { known_user }

    it 'writes a merge_quarantine row when a per-record save raises ActiveRecord::RecordInvalid' do
      # Force the membership create! to raise mid-apply.
      invalid_membership = Membership.new
      invalid_membership.errors.add(:base, 'forced invalid for spec')
      allow(Membership).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(invalid_membership))

      expect do
        described_class.new(merge_plan: bad_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change(MergeQuarantineRecord, :count).by(1)

      q = MergeQuarantineRecord.last
      expect(q.entity_type).to eq('membership')
      expect(q.entity_key).to eq(known_user.email)
      expect(q.original_archive_data).to include('email' => known_user.email)
      expect(q.validation_errors['message']).to include('Validation failed')
    end

    it 'continues applying the rest of the plan after a quarantine event' do
      # Force a per-record failure on the membership path
      bad_membership = Membership.new
      bad_membership.errors.add(:base, 'spec failure')
      allow(Membership).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(bad_membership))

      # Now add an unrelated change that should still apply
      target_rule = component.rules.first
      bad_plan.add_field_changes(target_rule.rule_id, [
                                   Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
                                     field: 'fixtext', from: target_rule.fixtext, to: 'still wins',
                                     resolution: :auto_theirs, locked: false, reason: ''
                                   )
                                 ])

      described_class.new(merge_plan: bad_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(target_rule.reload.fixtext).to eq('still wins') # rule write was NOT rolled back by membership failure
      expect(MergeQuarantineRecord.count).to eq(1)
    end

    it 'returns a warning on the MergeResult naming the quarantined record' do
      bad_membership = Membership.new
      bad_membership.errors.add(:base, 'spec failure')
      allow(Membership).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(bad_membership))

      result = described_class.new(merge_plan: bad_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(result.warnings.join).to match(/quarantined/i)
      expect(result.warnings.join).to include(known_user.email)
    end

    it 'quarantines a rule-write failure via savepoint while letting other rule writes commit' do
      rule_a, rule_b = component.rules.first(2)
      plan_with_two_rules = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      plan_with_two_rules.add_field_changes(rule_a.rule_id, [
                                              Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
                                                field: 'fixtext', from: rule_a.fixtext, to: 'A WINS',
                                                resolution: :auto_theirs, locked: false, reason: ''
                                              )
                                            ])
      plan_with_two_rules.add_field_changes(rule_b.rule_id, [
                                              Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
                                                field: 'fixtext', from: rule_b.fixtext, to: 'B WINS',
                                                resolution: :auto_theirs, locked: false, reason: ''
                                              )
                                            ])

      # Force rule_b.save! to raise RecordInvalid mid-apply via the AR
      # instance the applier loaded (eager_loaded_rules indexes by rule_id).
      allow_any_instance_of(BaseRule).to receive(:save!) do |inst|
        if inst.rule_id == rule_b.rule_id
          inst.errors.add(:base, 'rule_b spec failure')
          raise ActiveRecord::RecordInvalid, inst
        end
        inst.save(validate: false)
      end

      described_class.new(merge_plan: plan_with_two_rules, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(rule_a.reload.fixtext).to eq('A WINS') # savepoint protected
      expect(rule_b.reload.fixtext).not_to eq('B WINS') # rule_b savepoint rolled back
      q = MergeQuarantineRecord.where(entity_type: 'rule').last
      expect(q.entity_key).to include(rule_b.rule_id)
    end

    it 'persists buffered quarantine rows even when a later step rolls back the outer txn' do
      # apply_all order: rule_field_changes (1st) → ... → apply_new_satisfactions.
      # Quarantine rule write #5, then have apply_new_satisfactions raise
      # StandardError → outer rescue catches → outer txn rolls back. drain
      # then runs post-rescue and writes the buffered quarantine row.
      target_rule = component.rules.first
      rule_plan = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      rule_plan.add_field_changes(target_rule.rule_id, [
                                    Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
                                      field: 'fixtext', from: target_rule.fixtext, to: 'will-quarantine',
                                      resolution: :auto_theirs, locked: false, reason: ''
                                    )
                                  ])

      allow_any_instance_of(BaseRule).to receive(:save!) do |inst|
        inst.errors.add(:base, '#5 forced RecordInvalid')
        raise ActiveRecord::RecordInvalid, inst
      end

      applier = described_class.new(merge_plan: rule_plan, component: component, source: 'theirs', archive_bytes: archive_bytes)
      allow(applier).to receive(:apply_new_satisfactions).and_raise(StandardError, 'simulated #6 explosion')

      result = applier.call

      expect(result.success?).to be(false)
      expect(MergeQuarantineRecord.where(entity_type: 'rule').count).to eq(1)
      q = MergeQuarantineRecord.where(entity_type: 'rule').last
      expect(q.entity_key).to include(target_rule.rule_id)
      expect(result.warnings.join).to match(/quarantined/i)
    end
  end

  describe '#call (audit correlation scope)' do
    let(:target_rule) { component.rules.first }
    let(:auto_plan) do
      p = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      p.add_field_changes(target_rule.rule_id, [
                            Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
                              field: 'fixtext', from: target_rule.fixtext, to: 'audit-test',
                              resolution: :auto_theirs, locked: false, reason: ''
                            )
                          ])
      p
    end

    it 'wraps the apply in VulcanAudit.with_correlation_scope keyed to sync_id' do
      expect(VulcanAudit).to receive(:with_correlation_scope).and_call_original

      described_class.new(merge_plan: auto_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
    end

    it 'tags each save audit_comment with "merge:{sync_id}"' do
      described_class.new(merge_plan: auto_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      event = ComponentSyncEvent.last
      audit = target_rule.audits.last
      expect(audit.comment).to eq("merge:#{event.sync_id}")
    end

    it 'all audit rows from one merge share the same request_uuid' do
      # Trigger TWO rule writes so we can verify both audits share a uuid
      second_rule = component.rules.second
      auto_plan.add_field_changes(second_rule.rule_id, [
                                    Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
                                      field: 'fixtext', from: second_rule.fixtext, to: 'audit-test-2',
                                      resolution: :auto_theirs, locked: false, reason: ''
                                    )
                                  ])

      described_class.new(merge_plan: auto_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      a1 = target_rule.audits.last
      a2 = second_rule.audits.last
      expect(a1.request_uuid).to eq(a2.request_uuid)
      expect(a1.request_uuid).to be_present
    end
  end

  describe '#call (component sync metadata)' do
    it 'sets component.last_sync_id, last_sync_at, last_sync_source on success' do
      now = Time.current
      described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call

      component.reload
      event = ComponentSyncEvent.last
      expect(component.last_sync_id).to eq(event.sync_id)
      expect(component.last_sync_at).to be_within(5.seconds).of(now)
      expect(component.last_sync_source).to eq('theirs')
    end

    it 'does NOT update sync metadata when the merge fails (status=failed)' do
      applier = described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes)
      allow(applier).to receive(:apply_all).and_raise(ActiveRecord::StatementInvalid.new('boom'))
      original_last_sync_id = component.last_sync_id

      applier.call

      expect(component.reload.last_sync_id).to eq(original_last_sync_id)
    end
  end

  describe '#call (closed-phase precondition)' do
    it 'refuses to apply against an open-phase component and marks the event failed' do
      open_component = create(:component, :open_comment_period)
      open_plan = Import::JsonArchive::Merge::Analyzer.new(
        merge_input: Import::JsonArchive::Merge::MergeInput.from_json_archive(build_backup_hash(open_component), manifest: manifest),
        component: open_component, strategy: strategy, manifest: manifest
      ).call

      result = described_class.new(merge_plan: open_plan, component: open_component, source: 'theirs', archive_bytes: archive_bytes).call

      expect(result.success?).to be(false)
      expect(result.errors.join).to match(/comment_phase/i)
      expect(ComponentSyncEvent.last.status).to eq('failed')
    end
  end

  describe '#call (eager-load + memoization contract)' do
    def captured_sql(&)
      queries = []
      callback = lambda do |_n, _s, _f, _id, payload|
        queries << payload[:sql] unless payload[:name] == 'SCHEMA'
      end
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &)
      queries
    end

    it 'plucks rule_id_map exactly once across import_new_reviews + apply_new_satisfactions' do
      target_rule = component.rules.first
      another_rule = create(:rule, component: component, rule_id: 'V-9999')
      new_review = {
        'external_id' => 71, 'rule_id' => target_rule.rule_id, 'action' => 'comment',
        'comment' => 'q', 'created_at' => Time.zone.local(2026, 6, 7).iso8601(6),
        'user_email' => 'q@example.com', 'user_name' => 'Q'
      }
      new_sat = { 'rule_id' => target_rule.rule_id, 'satisfied_by_rule_id' => another_rule.rule_id }
      mixed = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      mixed.add_review_partition(matched: [], only_ours: [], only_theirs: [new_review])
      mixed.add_satisfaction_partition(matched: [], only_ours: [], only_theirs: [new_sat])
      create(:user, email: 'q@example.com', name: 'Q').tap do |u|
        Membership.create!(user: u, membership: component.project, role: 'viewer')
      end

      sql = captured_sql do
        described_class.new(merge_plan: mixed, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end
      plucks = sql.grep(/SELECT "base_rules"\."rule_id", "base_rules"\."id" FROM "base_rules"/i)
      expect(plucks.size).to eq(1)
    end
  end

  describe '#call (review-conflict skip audit + idempotency v2-480.40)' do
    let(:target_rule) { component.rules.first }
    let(:existing_review) do
      create(:review, rule: target_rule, user: create(:user, email: 'cc@example.com'),
                      action: 'comment', section: 'check_content',
                      comment: 'existing', triage_status: 'concur')
    end
    let(:ours_h) do
      { 'external_id' => existing_review.id, 'rule_id' => target_rule.rule_id,
        'comment' => 'existing', 'created_at' => existing_review.created_at.iso8601(6),
        'triage_status' => 'concur' }
    end
    let(:theirs_h) { ours_h.merge('triage_status' => 'non_concur') }
    # Use a verb that's not :theirs/:ours so the skip path fires.
    let(:conflict_strategy) do
      Import::JsonArchive::Merge::Strategy.new(
        overrides: { review: { 'triage_status' => :conflict } }
      )
    end
    let(:conflict_plan) do
      p = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: conflict_strategy, manifest: manifest
      )
      p.add_review_partition(matched: [{ ours: ours_h, theirs: theirs_h }], only_ours: [], only_theirs: [])
      p
    end

    before { existing_review }

    it 'writes a skip MergeOperation row when verb=:conflict on a divergent review field' do
      expect do
        described_class.new(merge_plan: conflict_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.to change(MergeOperation.where(entity_type: 'review', operation: 'skip'), :count).by(1)

      op = MergeOperation.where(entity_type: 'review', operation: 'skip').last
      expect(op.field_name).to eq('triage_status')
      expect(op.source).to eq('conflict_resolved')
      expect(op.old_value).to eq('concur')
      expect(op.new_value).to eq('non_concur')
    end

    it 'a second apply against the same already-applied satisfaction does NOT log a duplicate insert (v2-480.40)' do
      anchor = component.rules.first
      satisfier = component.rules.second
      sat_hash = { 'rule_id' => anchor.rule_id, 'satisfied_by_rule_id' => satisfier.rule_id }
      # Pre-create the satisfaction so upsert_all hits the on_duplicate path.
      RuleSatisfaction.create!(rule_id: anchor.id, satisfied_by_rule_id: satisfier.id)
      idempotent_plan = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      idempotent_plan.add_satisfaction_partition(matched: [], only_ours: [], only_theirs: [sat_hash])

      expect do
        described_class.new(merge_plan: idempotent_plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
      end.not_to(change(MergeOperation.where(entity_type: 'satisfaction', operation: 'insert'), :count))
    end
  end

  describe '#call (advisory lock + reload-locked precondition)' do
    subject(:result) do
      described_class.new(merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes).call
    end

    it 'acquires pg_advisory_xact_lock on component.id inside the apply transaction' do
      captured_sql = []
      allow(ActiveRecord::Base.connection).to receive(:execute).and_wrap_original do |orig, sql|
        captured_sql << sql.to_s
        orig.call(sql)
      end

      result

      expect(captured_sql.any? { |s| s.include?("pg_advisory_xact_lock(#{component.id})") }).to be(true)
    end

    it 'takes the pre-merge snapshot inside the apply transaction (not before)' do
      txn_open_at_snapshot = nil
      allow(Import::JsonArchive::Merge::SnapshotManager)
        .to receive(:create_snapshot) do
          txn_open_at_snapshot = ActiveRecord::Base.connection.transaction_open?
          '/tmp/snap-in-txn.zip'
        end

      result

      expect(txn_open_at_snapshot).to be(true)
    end

    it 'fails with PreconditionError when the component is destroyed mid-apply' do
      allow(component).to receive(:lock!).and_raise(ActiveRecord::RecordNotFound)

      expect(result.success?).to be(false)
      expect(result.errors.join).to match(/destroyed/i)
      expect(ComponentSyncEvent.last.status).to eq('failed')
    end

    it 'fails when comment_phase is reopened between the fast-fail and the locked re-check' do
      allow(component).to receive(:lock!) do
        component.assign_attributes(comment_phase: 'reopened_during_apply')
        component
      end

      expect(result.success?).to be(false)
      expect(result.errors.join).to match(/comment_phase/i)
      expect(ComponentSyncEvent.last.status).to eq('failed')
    end
  end

  describe '#call (archive_hash replay protection)' do
    it 'refuses to re-apply an archive whose SHA-256 already exists on a prior applied sync_event' do
      prior_hash = Digest::SHA256.hexdigest(archive_bytes)
      ComponentSyncEvent.create!(
        component: component, sync_id: SecureRandom.uuid,
        source: 'theirs', direction: 'inbound', status: 'applied',
        archive_hash: prior_hash
      )

      result = described_class.new(
        merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes
      ).call

      expect(result.success?).to be(false)
      expect(result.errors.join).to match(/already applied/i)
    end

    it 'allows re-apply when the prior sync_event with the same hash is failed (retry path)' do
      prior_hash = Digest::SHA256.hexdigest(archive_bytes)
      ComponentSyncEvent.create!(
        component: component, sync_id: SecureRandom.uuid,
        source: 'theirs', direction: 'inbound', status: 'failed',
        archive_hash: prior_hash
      )

      result = described_class.new(
        merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes
      ).call

      expect(result.success?).to be(true)
    end

    it 'allows apply on a different component with the same archive (cross-component replay is legit)' do
      other_component = create(:component, :closed_comment_phase)
      prior_hash = Digest::SHA256.hexdigest(archive_bytes)
      ComponentSyncEvent.create!(
        component: other_component, sync_id: SecureRandom.uuid,
        source: 'theirs', direction: 'inbound', status: 'applied',
        archive_hash: prior_hash
      )

      result = described_class.new(
        merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes
      ).call

      expect(result.success?).to be(true)
    end
  end

  describe '#call (actor attribution v2-480.37)' do
    let(:target_rule) { component.rules.first }
    let(:operator) { create(:user, email: 'op@example.com', name: 'Op Erator') }
    let(:new_review_hash) do
      {
        'external_id' => 7777, 'rule_id' => target_rule.rule_id, 'action' => 'comment',
        'section' => 'check_content', 'comment' => 'attributed',
        'created_at' => Time.zone.local(2026, 6, 8, 12, 0).iso8601(6),
        'user_email' => operator.email, 'user_name' => operator.name
      }
    end
    let(:plan_with_review) do
      p = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      p.add_review_partition(matched: [], only_ours: [], only_theirs: [new_review_hash])
      p
    end

    before do
      Membership.create!(user: operator, membership: component.project, role: 'viewer')
    end

    it 'bulk-inserts an Audited::Audit row per imported review tagged with actor + request_uuid' do
      described_class.new(
        merge_plan: plan_with_review, component: component, source: 'theirs',
        archive_bytes: archive_bytes, actor: operator
      ).call

      imported = Review.where(rule_id: target_rule.id, comment: 'attributed').first
      audits = Audited.audit_class.where(auditable_type: 'Review', auditable_id: imported.id)
      expect(audits.count).to be >= 1
      audit = audits.find { |a| a.action == 'create' && a.comment&.start_with?('merge:') }
      expect(audit).not_to be_nil
      expect(audit.user_id).to eq(operator.id)
      expect(audit.request_uuid).to eq(ComponentSyncEvent.last.sync_id)
    end

    it 'does NOT bulk-insert review audits when actor is nil' do
      described_class.new(
        merge_plan: plan_with_review, component: component, source: 'theirs',
        archive_bytes: archive_bytes, actor: nil
      ).call

      imported = Review.where(rule_id: target_rule.id, comment: 'attributed').first
      bulk_audits = Audited.audit_class.where(auditable_type: 'Review', auditable_id: imported.id,
                                              action: 'create').where("comment LIKE 'merge:%'")
      expect(bulk_audits).to be_empty
    end

    it 'warns when actor is nil for source=theirs' do
      result = described_class.new(
        merge_plan: plan_with_review, component: component, source: 'theirs',
        archive_bytes: archive_bytes, actor: nil
      ).call

      expect(result.warnings.join).to match(/actor not provided.*theirs/i)
    end

    it 'stamps audit_comment_for_merge on imported memberships' do
      new_user = create(:user, email: 'newbie@example.com', name: 'Newbie')
      membership_plan = Import::JsonArchive::Merge::MergePlan.new(
        component_id: component.id, strategy: strategy, manifest: manifest
      )
      membership_plan.add_membership_partition(
        matched: [], only_ours: [], only_theirs: [{ 'email' => new_user.email, 'role' => 'viewer' }]
      )

      described_class.new(
        merge_plan: membership_plan, component: component, source: 'theirs',
        archive_bytes: archive_bytes, actor: operator
      ).call

      imported = Membership.find_by(user: new_user, membership: component.project)
      create_audit = imported.audits.find_by(action: 'create')
      expect(create_audit&.comment).to start_with('merge:')
    end
  end

  describe '#call (one pending sync per component invariant)' do
    it 'refuses to start a second apply while another sync is still pending' do
      ComponentSyncEvent.create!(
        component: component, sync_id: SecureRandom.uuid,
        source: 'theirs', direction: 'inbound', status: 'pending'
      )

      result = described_class.new(
        merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes
      ).call

      expect(result.success?).to be(false)
      expect(result.errors.join).to match(/already in progress|pending/i)
    end

    it 'allows a new apply once the prior pending event has transitioned to applied' do
      prior = ComponentSyncEvent.create!(
        component: component, sync_id: SecureRandom.uuid,
        source: 'theirs', direction: 'inbound', status: 'pending'
      )
      prior.update!(status: 'applied')

      result = described_class.new(
        merge_plan: plan, component: component, source: 'theirs', archive_bytes: archive_bytes
      ).call

      expect(result.success?).to be(true)
    end
  end
end
