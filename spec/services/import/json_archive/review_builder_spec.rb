# frozen_string_literal: true

require 'rails_helper'

# ReviewBuilder uses Review.insert! to bypass
# create-time callbacks (audit-resume + before_create state machine). That
# also bypasses model validators. A malicious or legacy archive could carry
# review records that violate validators added since the snapshot was made:
#   - duplicate_status_requires_target  (triage_status='duplicate' + nil target)
#   - responding_to_must_be_same_rule   (reply pointing across rules)
#   - duplicate_of_must_be_same_component (cross-component duplicate ref)
#   - inclusion validators on triage_status / section
#
# Behavior under test: after the insert + thread-relink passes, ReviewBuilder
# re-loads each inserted review, runs `valid?`, and on failure emits a
# warning (with external_id + error messages) AND deletes the offending row
# to keep the post-import DB clean. Children that point at a removed parent
# cascade-delete via FK semantics.
RSpec.describe Import::JsonArchive::ReviewBuilder do
  let_it_be(:project) { create(:project) }
  let_it_be(:component) do
    create(:component, project: project,
                       comment_phase: 'open',
                       comment_period_starts_at: 1.day.ago,
                       comment_period_ends_at: 1.day.from_now)
  end
  let_it_be(:other_component) { create(:component, project: project) }
  let_it_be(:rule_a) { component.rules.first }
  let_it_be(:rule_b) { component.rules.second }
  let_it_be(:rule_in_other) { other_component.rules.first }
  let_it_be(:user) do
    Membership.find_or_create_by!(user: create(:user), membership: project) { |m| m.role = 'viewer' }.user
  end

  let(:result) { Import::Result.new }
  let(:rule_id_map) do
    { rule_a.rule_id => rule_a.id,
      rule_b.rule_id => rule_b.id,
      rule_in_other.rule_id => rule_in_other.id }
  end

  def review_attrs(overrides = {})
    {
      'external_id' => 1001,
      'rule_id' => rule_a.rule_id,
      'action' => 'comment',
      'comment' => 'sample',
      'user_email' => user.email,
      'user_name' => user.name,
      'created_at' => Time.current.iso8601
    }.merge(overrides.transform_keys(&:to_s))
  end

  describe '#build_all post-insert validation' do
    it 'imports a clean archive with no warnings' do
      data = [review_attrs(external_id: 1, comment: 'clean comment')]
      count = described_class.new(data, rule_id_map, result).build_all
      expect(count).to eq(1)
      expect(result.warnings).to be_empty
      expect(Review.where(comment: 'clean comment').count).to eq(1)
    end

    it 'warns and removes a duplicate-status review with no target' do
      data = [review_attrs(
        external_id: 2001,
        comment: 'invalid duplicate sample',
        triage_status: 'duplicate',
        duplicate_of_external_id: nil
      )]
      count = described_class.new(data, rule_id_map, result).build_all
      expect(count).to eq(0)
      expect(result.warnings).to include(
        a_string_matching(/Review 2001:.*failed validation.*duplicate/i)
      )
      expect(Review.where(comment: 'invalid duplicate sample')).to be_empty
    end

    it 'warns and removes a reply pointing at a comment on a different rule' do
      data = [
        review_attrs(external_id: 3001, comment: 'parent on rule A', rule_id: rule_a.rule_id),
        review_attrs(external_id: 3002, comment: 'reply on rule B',
                     rule_id: rule_b.rule_id, responding_to_external_id: 3001)
      ]
      count = described_class.new(data, rule_id_map, result).build_all
      expect(count).to eq(1)
      expect(result.warnings).to include(
        a_string_matching(/Review 3002:.*same rule/i)
      )
      expect(Review.where(comment: 'parent on rule A')).to exist
      expect(Review.where(comment: 'reply on rule B')).to be_empty
    end

    it 'warns each invalid review individually and counts only the valid ones' do
      data = [
        review_attrs(external_id: 5001, comment: 'good A'),
        review_attrs(external_id: 5002, comment: 'bad A',
                     triage_status: 'duplicate', duplicate_of_external_id: nil),
        review_attrs(external_id: 5003, comment: 'good B', rule_id: rule_b.rule_id)
      ]
      count = described_class.new(data, rule_id_map, result).build_all
      expect(count).to eq(2)
      expect(result.warnings.size).to eq(1)
      expect(result.warnings.first).to match(/5002/)
    end
  end

  # Component-level audit row records WHICH
  # external_ids were imported FROM WHICH archive. Provides recovery trail
  # so admin_destroy → re-import can be reconstructed. Without this, audit
  # laundering is possible: destroy review (audit row keeps history) then
  # re-import via Review.insert! (no audit) wipes the lifecycle trail.
  describe '#build_all writes a Component-level import audit' do
    let_it_be(:importing_admin) do
      Membership.find_or_create_by!(user: create(:user, name: 'Admin'),
                                    membership: project) { |m| m.role = 'admin' }.user
    end
    let(:manifest) do
      { 'vulcan_version' => '2.3.5',
        'exported_at' => '2026-04-30T12:00:00Z',
        'backup_format_version' => '1.0' }
    end

    it 'writes one audit row on the component with action=import_reviews' do
      data = [review_attrs(external_id: 9001, comment: 'audit-test 1')]
      builder = described_class.new(data, rule_id_map, result,
                                    component: component, manifest: manifest,
                                    imported_by: importing_admin)
      expect { builder.build_all }.to change {
        component.audits.where(action: 'import_reviews').count
      }.by(1)
    end

    it 'records the external_ids of imported reviews in audited_changes' do
      data = [
        review_attrs(external_id: 9101, comment: 'a'),
        review_attrs(external_id: 9102, comment: 'b')
      ]
      described_class.new(data, rule_id_map, result,
                          component: component, manifest: manifest,
                          imported_by: importing_admin).build_all
      audit = component.audits.where(action: 'import_reviews').last
      expect(audit.audited_changes['review_external_ids']).to contain_exactly(9101, 9102)
    end

    it 'records archive vulcan_version + exported_at in audited_changes' do
      data = [review_attrs(external_id: 9201, comment: 'manifest test')]
      described_class.new(data, rule_id_map, result,
                          component: component, manifest: manifest,
                          imported_by: importing_admin).build_all
      audit = component.audits.where(action: 'import_reviews').last
      expect(audit.audited_changes['archive_vulcan_version']).to eq('2.3.5')
      expect(audit.audited_changes['archive_exported_at']).to eq('2026-04-30T12:00:00Z')
    end

    it 'attributes the audit to the importing admin' do
      data = [review_attrs(external_id: 9301, comment: 'attribution test')]
      described_class.new(data, rule_id_map, result,
                          component: component, manifest: manifest,
                          imported_by: importing_admin).build_all
      audit = component.audits.where(action: 'import_reviews').last
      expect(audit.user_id).to eq(importing_admin.id)
    end

    it 'writes no audit row when no reviews import successfully' do
      data = []
      described_class.new(data, rule_id_map, result,
                          component: component, manifest: manifest,
                          imported_by: importing_admin).build_all
      expect(component.audits.where(action: 'import_reviews')).to be_empty
    end
  end

  # defensive transaction
  # wrap on build_all. JsonArchiveImporter#perform_import already wraps
  # in ActiveRecord::Base.transaction (acts as outer txn → savepoint
  # nesting), but ReviewBuilder.new explicitly supports direct/test
  # callers (constructor signature comment at review_builder.rb:24).
  # Without an inner txn, a direct caller hitting an exception in
  # pass 2 (relink_threaded_refs) or pass 3 (drop_invalid_reviews)
  # would leave the pass-1 inserts as orphan rows.
  describe '#build_all transaction wrap' do
    it 'rolls back pass-1 inserts when relink_threaded_refs raises' do
      data = [
        review_attrs(external_id: 7001, comment: 'rollback test 1'),
        review_attrs(external_id: 7002, comment: 'rollback test 2', rule_id: rule_b.rule_id)
      ]
      builder = described_class.new(data, rule_id_map, result)
      allow(builder).to receive(:relink_threaded_refs).and_raise(StandardError, 'simulated mid-pass failure')

      expect { builder.build_all }.to raise_error(StandardError, /simulated mid-pass failure/)
      expect(Review.where(comment: ['rollback test 1', 'rollback test 2'])).to be_empty
    end

    it 'rolls back pass-1 inserts when drop_invalid_reviews raises' do
      data = [review_attrs(external_id: 7101, comment: 'rollback drop-invalid')]
      builder = described_class.new(data, rule_id_map, result)
      allow(builder).to receive(:drop_invalid_reviews).and_raise(StandardError, 'simulated drop failure')

      expect { builder.build_all }.to raise_error(StandardError, /simulated drop failure/)
      expect(Review.where(comment: 'rollback drop-invalid')).to be_empty
    end
  end

  # pre-fix, when the archive's
  # commenter user_email/user_name didn't resolve to a User on this
  # instance, ReviewBuilder warned + skipped the review entirely. That
  # destroyed the audit trail / disposition record. Now that step A2
  # makes belongs_to :user optional and step A1 added
  # commenter_imported_email/name columns, we can preserve the row with
  # user_id NULL + commenter_imported_* populated. Mirrors the existing
  # attribution_attrs pattern used for triage_set_by + adjudicated_by.
  describe '#build_all unresolved commenter' do
    it 'imports the review with commenter_imported_email/name when user does not resolve' do
      data = [review_attrs(
        external_id: 8001,
        comment: 'unresolved commenter test',
        user_email: 'former@no-such-domain.example',
        user_name: 'Former Commenter'
      )]
      count = described_class.new(data, rule_id_map, result).build_all
      expect(count).to eq(1)
      review = Review.find_by(comment: 'unresolved commenter test')
      expect(review.user_id).to be_nil
      expect(review.commenter_imported_email).to eq('former@no-such-domain.example')
      expect(review.commenter_imported_name).to eq('Former Commenter')
    end

    it 'records a warning naming the unresolved commenter' do
      data = [review_attrs(
        external_id: 8002,
        comment: 'warning text test',
        user_email: 'unknown-commenter@no-such-domain.example',
        user_name: 'Unknown'
      )]
      described_class.new(data, rule_id_map, result).build_all
      expect(result.warnings).to include(
        a_string_matching(/8002.*unknown-commenter@no-such-domain\.example.*imported_email/)
      )
    end

    it 'still uses the resolved User when one matches by email (no commenter_imported_* set)' do
      data = [review_attrs(external_id: 8003, comment: 'resolved commenter', user_email: user.email)]
      described_class.new(data, rule_id_map, result).build_all
      review = Review.find_by(comment: 'resolved commenter')
      expect(review.user_id).to eq(user.id)
      expect(review.commenter_imported_email).to be_nil
      expect(review.commenter_imported_name).to be_nil
    end

    it 'does not import when both user_email and user_name are blank (no attribution at all)' do
      # An archive entry with no commenter info anywhere is genuinely
      # unrecoverable — drop it with a warning rather than insert a
      # row that has no provenance whatsoever.
      data = [review_attrs(
        external_id: 8004,
        comment: 'no attribution at all',
        user_email: nil,
        user_name: nil
      )]
      count = described_class.new(data, rule_id_map, result).build_all
      expect(count).to eq(0)
      expect(Review.where(comment: 'no attribution at all')).to be_empty
      expect(result.warnings).to include(a_string_matching(/8004.*no commenter attribution/i))
    end
  end
end
