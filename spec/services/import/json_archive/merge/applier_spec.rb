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
