# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review do
  # Expensive setup: SRG parse + component creation — do once
  let_it_be(:shared_srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_Web_Server_SRG_V4R4_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    srg
  end
  let_it_be(:shared_p1) { Project.create(name: 'P1') }
  let_it_be(:shared_p2) { Project.create(name: 'P2') }
  let_it_be(:shared_admin) { create(:user, admin: true) }
  let_it_be(:shared_p_admin) { create(:user) }
  let_it_be(:shared_p_reviewer) { create(:user) }
  let_it_be(:shared_p_author) { create(:user) }
  let_it_be(:shared_p_viewer) { create(:user) }
  let_it_be(:shared_other_p_admin) { create(:user) }
  let_it_be(:shared_component, refind: true) do
    Component.create!(project: shared_p1, name: 'Photon OS 3', title: 'Photon OS 3 STIG',
                      version: 'Photon OS 3 V1R1', prefix: 'PHOS-03', based_on: shared_srg)
  end
  let_it_be(:shared_rule, refind: true) do
    Rule.create(component: shared_component, rule_id: 'P1-R1', status: 'Applicable - Configurable',
                rule_severity: 'medium', srg_rule: shared_srg.srg_rules.first)
  end

  before do
    # Set up memberships per-example (rolled back by savepoint)
    Membership.create(user: shared_p_admin, membership: shared_p1, role: 'admin')
    Membership.create(user: shared_p_reviewer, membership: shared_p1, role: 'reviewer')
    Membership.create(user: shared_p_author, membership: shared_p1, role: 'author')
    Membership.create(user: shared_p_viewer, membership: shared_p1, role: 'viewer')
    Membership.create(user: shared_other_p_admin, membership: shared_p2, role: 'admin')
    # Expose via instance vars for existing test code
    @p1 = shared_p1
    @p2 = shared_p2
    @admin = shared_admin
    @p_admin = shared_p_admin
    @p_reviewer = shared_p_reviewer
    @p_author = shared_p_author
    @p_viewer = shared_p_viewer
    @other_p_admin = shared_other_p_admin
    @p1_c1 = shared_component
    @p1r1 = shared_rule
  end

  context 'failed take review action' do
    it 'does not take action for invalid review' do
      # Sanity check on initial state
      expect(@p1r1.review_requestor_id).to be_nil
      expect(@p1r1.locked).to be(false)

      # Do something we can't do right now
      review = Review.new(action: 'approve', comment: '...', user: @p_admin, rule: @p1r1)

      expect(review.save).to be(false)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to be_nil
      expect(@p1r1.locked).to be(false)
    end

    it 'does not save if rule fails to save' do
      # Change a non-review field with the subsequent review fields
      @p1r1.status = '...'

      # Sanity check on initial state
      expect(@p1r1.review_requestor_id).to be_nil
      expect(@p1r1.locked).to be(false)

      review = Review.new(action: 'request_review', comment: '...', user: @p_admin, rule: @p1r1)
      expect(review.save).to be(false)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to be_nil
      expect(@p1r1.locked).to be(false)
    end
  end

  context 'sucessful take review action' do
    it 'takes no action on comment' do
      expect(@p1r1.review_requestor_id).to be_nil
      expect(@p1r1.locked).to be(false)
      Review.create(action: 'comment', comment: '...', user: @p_admin, rule: @p1r1)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to be_nil
      expect(@p1r1.locked).to be(false)
    end

    it 'take action on request_review' do
      Review.create(action: 'request_review', comment: '...', user: @p_admin, rule: @p1r1)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to eq(@p_admin.id)
      expect(@p1r1.locked).to be(false)
    end

    it 'take action on revoke_review_request' do
      @p1r1.update(review_requestor: @p_admin)
      Review.create(action: 'revoke_review_request', comment: '...', user: @p_admin, rule: @p1r1)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to be_nil
      expect(@p1r1.locked).to be(false)
    end

    it 'take action on request_changes' do
      @p1r1.update(review_requestor: @p_admin)
      Review.create(action: 'request_changes', comment: '...', user: @p_admin, rule: @p1r1)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to be_nil
      expect(@p1r1.locked).to be(false)
    end

    it 'take action on approve' do
      @p1r1.update(review_requestor: @p_admin)
      Review.create(action: 'approve', comment: '...', user: @p_admin, rule: @p1r1)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to be_nil
      expect(@p1r1.locked).to be(true)
    end

    it 'take action on lock_control' do
      Review.create(action: 'lock_control', comment: '...', user: @p_admin, rule: @p1r1)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to be_nil
      expect(@p1r1.locked).to be(true)
    end

    it 'take action on unlock_control' do
      @p1r1.update(locked: true)
      Review.create(action: 'unlock_control', comment: '...', user: @p_admin, rule: @p1r1)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to be_nil
      expect(@p1r1.locked).to be(false)
    end
  end

  context 'validations on invalid reviews' do
    it 'blocks non-members from any action' do
      %w[
        comment
        request_review
        revoke_review_request
        request_changes
        approve
        lock_control
        unlock_control
      ].each do |action|
        review = Review.new(action: action, comment: '...', user: @other_p_admin, rule: @p1r1)
        review.valid?
        expect(review.errors[:base]).to include('You have no permissions on this project')
      end
    end

    it 'blocks request_review when rule is locked' do
      @p1r1.update(locked: true)
      review = Review.new(action: 'request_review', comment: '...', user: @p_admin, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Cannot request a review on a locked control')
    end

    it 'blocks request_review when rule is already under review' do
      @p1r1.update(review_requestor: @p_author)
      review = Review.new(action: 'request_review', comment: '...', user: @p_admin, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Control is already under review')
    end

    it 'blocks revoke_review_request when rule is not under review' do
      review = Review.new(action: 'revoke_review_request', comment: '...', user: @p_admin, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Control is not currently under review')
    end

    it 'blocks revoke_review_request when not admin or review requestor' do
      @p1r1.update(review_requestor: @p_author)
      review = Review.new(action: 'revoke_review_request', comment: '...', user: @p_reviewer, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Only the requestor or an admin can revoke a review request')

      review.user = @admin
      expect(review).to be_valid

      review.user = @p_admin
      expect(review).to be_valid

      review.user = @p_author
      expect(review).to be_valid
    end

    it 'blocks request_changes when rule is not under review' do
      @p1r1.update(locked: true)
      review = Review.new(action: 'request_changes', comment: '...', user: @p_admin, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Control is not currently under review')
    end

    it 'blocks request_changes when not admin or reviewer' do
      @p1r1.update(review_requestor: @p_author)
      review = Review.new(action: 'request_changes', comment: '...', user: @p_author, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Only admins and reviewers can request changes')

      review.user = @admin
      expect(review).to be_valid

      review.user = @p_admin
      expect(review).to be_valid

      review.user = @p_reviewer
      expect(review).to be_valid
    end

    it 'blocks request_changes when reviewer is the review requestor' do
      @p1r1.update(review_requestor: @p_reviewer)
      review = Review.new(action: 'request_changes', comment: '...', user: @p_reviewer, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Reviewers cannot review their own review requests')
    end

    it 'blocks approve when control is not under review' do
      review = Review.new(action: 'approve', comment: '...', user: @p_admin, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Control is not currently under review')
    end

    it 'blocks approve when not admin or reviewer' do
      @p1r1.update(review_requestor: @p_author)
      review = Review.new(action: 'approve', comment: '...', user: @p_author, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Only admins and reviewers can approve')

      review.user = @admin
      expect(review).to be_valid

      review.user = @p_admin
      expect(review).to be_valid

      review.user = @p_reviewer
      expect(review).to be_valid
    end

    it 'blocks approve when reviewer is the review requestor' do
      @p1r1.update(review_requestor: @p_reviewer)
      review = Review.new(action: 'approve', comment: '...', user: @p_reviewer, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Reviewers cannot review their own review requests')
    end

    it 'blocks lock_control when not admin' do
      review = Review.new(action: 'lock_control', comment: '...', user: @p_author, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Only an admin can lock')

      review.user = @p_reviewer
      review.valid?
      expect(review.errors[:base]).to include('Only an admin can lock')

      review.user = @admin
      expect(review).to be_valid

      review.user = @p_admin
      expect(review).to be_valid
    end

    it 'blocks lock_control when rule is under review' do
      @p1r1.update(review_requestor: @p_reviewer)
      review = Review.new(action: 'lock_control', comment: '...', user: @p_admin, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Cannot lock a control that is currently under review')
    end

    it 'blocks lock_control when rule is already locked' do
      @p1r1.update(locked: true)
      review = Review.new(action: 'lock_control', comment: '...', user: @p_admin, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Control is already locked')
    end

    it 'blocks unlock_control when not admin' do
      @p1r1.update(locked: true)
      review = Review.new(action: 'unlock_control', comment: '...', user: @p_author, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Only an admin can unlock')

      review.user = @p_reviewer
      review.valid?
      expect(review.errors[:base]).to include('Only an admin can unlock')

      review.user = @admin
      expect(review).to be_valid

      review.user = @p_admin
      expect(review).to be_valid
    end

    it 'blocks unlock_control when rule is under review' do
      @p1r1.update(review_requestor: @p_reviewer)
      review = Review.new(action: 'unlock_control', comment: '...', user: @p_admin, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Cannot unlock a control that is currently under review')
    end

    it 'blocks unlock_control when rule is already unlocked' do
      review = Review.new(action: 'unlock_control', comment: '...', user: @p_admin, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Control is already unlocked')
    end
  end

  context 'validations on valid reviews' do
    it 'allows any member, including viewers, to comment' do
      [
        @admin,
        @p_admin,
        @p_reviewer,
        @p_author,
        @p_viewer
      ].each do |user|
        review = Review.new(action: 'comment', comment: '...', user: user, rule: @p1r1)
        role = user.effective_permissions(@p1r1.component) || 'site-admin'
        expect(review).to be_valid, "expected #{user} (membership role: #{role}) to be able to comment"
      end
    end
  end

  context 'action inclusion validation' do
    it 'rejects an unknown action string' do
      review = Review.new(action: 'definitely_not_a_real_action', comment: '...', user: @p_admin, rule: @p1r1)
      expect(review).not_to be_valid
      expect(review.errors[:action].join).to match(/not a recognized review action/)
    end

    it 'accepts every action listed in Review::VALID_ACTIONS' do
      Review::VALID_ACTIONS.each do |action_name|
        review = Review.new(action: action_name, comment: '...', user: @p_admin, rule: @p1r1)
        review.valid?
        expect(review.errors[:action]).to be_empty,
                                          "action #{action_name.inspect} unexpectedly failed inclusion validator"
      end
    end
  end

  context 'viewer permission boundaries' do
    it 'rejects a viewer attempting to approve' do
      @p1r1.update(review_requestor: @p_author)
      review = Review.new(action: 'approve', comment: 'lgtm', user: @p_viewer, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Only admins and reviewers can approve')
    end

    it 'rejects a viewer attempting to request_changes' do
      @p1r1.update(review_requestor: @p_author)
      review = Review.new(action: 'request_changes', comment: 'nope', user: @p_viewer, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Only admins and reviewers can request changes')
    end

    it 'rejects a viewer attempting to lock_control' do
      review = Review.new(action: 'lock_control', comment: 'lock!', user: @p_viewer, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Only an admin can lock')
    end

    it 'rejects a viewer attempting to request_review' do
      review = Review.new(action: 'request_review', comment: 'please look', user: @p_viewer, rule: @p1r1)
      review.valid?
      expect(review.errors[:base]).to include('Only admins, reviewers, and authors can request a review')
    end
  end

  context 'ACTION_PERMISSIONS map (per-action role gate)' do
    it 'rejects a viewer attempting request_review' do
      review = Review.new(action: 'request_review', comment: 'try', user: @p_viewer, rule: @p1r1)
      review.valid?
      expect(review.errors[:base].join).to match(/insufficient permissions to request_review/i)
    end

    it 'rejects a viewer attempting revoke_review_request' do
      @p1r1.update(review_requestor: @p_author)
      review = Review.new(action: 'revoke_review_request', comment: 'try', user: @p_viewer, rule: @p1r1)
      review.valid?
      expect(review.errors[:base].join).to match(/insufficient permissions to revoke_review_request/i)
    end

    it 'rejects a viewer attempting request_changes via the role gate' do
      review = Review.new(action: 'request_changes', comment: 'try', user: @p_viewer, rule: @p1r1)
      review.valid?
      expect(review.errors[:base].join).to match(/insufficient permissions to request_changes/i)
    end

    it 'rejects an author attempting approve via the role gate' do
      review = Review.new(action: 'approve', comment: 'lgtm', user: @p_author, rule: @p1r1)
      review.valid?
      expect(review.errors[:base].join).to match(/insufficient permissions to approve/i)
    end

    it 'rejects an author attempting lock_control via the role gate' do
      review = Review.new(action: 'lock_control', comment: 'lock', user: @p_author, rule: @p1r1)
      review.valid?
      expect(review.errors[:base].join).to match(/insufficient permissions to lock_control/i)
    end

    it 'allows a viewer to comment (the only mutating action they can perform)' do
      review = Review.new(action: 'comment', comment: 'looks good', user: @p_viewer, rule: @p1r1)
      review.valid?
      expect(review.errors[:base].grep(/insufficient permissions/i)).to be_empty
    end

    it 'allows an admin to perform every action (smoke check across the map)' do
      %w[comment request_review request_changes approve lock_control unlock_control].each do |action|
        review = Review.new(action: action, comment: 'x', user: @p_admin, rule: @p1r1)
        review.valid?
        perm_errors = review.errors[:base].grep(/insufficient permissions/i)
        expect(perm_errors).to be_empty,
                               "admin unexpectedly blocked from #{action}: #{perm_errors.inspect}"
      end
    end
  end

  context 'comment-action length cap' do
    it 'rejects a comment-action review longer than 4000 chars' do
      review = Review.new(action: 'comment', comment: 'x' * 4001, user: @p_viewer, rule: @p1r1)
      review.valid?
      expect(review.errors[:comment].join).to match(/too long/i)
    end

    it 'allows a comment-action review at exactly 4000 chars' do
      review = Review.new(action: 'comment', comment: 'x' * 4000, user: @p_viewer, rule: @p1r1)
      review.valid?
      expect(review.errors[:comment]).to be_empty
    end

    it 'allows other actions up to the configured input_limits.review_comment' do
      long_text = 'x' * 4500
      @p1r1.update(review_requestor: @p_author)
      review = Review.new(action: 'request_changes', comment: long_text, user: @p_admin, rule: @p1r1)
      review.valid?
      expect(review.errors[:comment]).to be_empty
    end
  end

  describe 'triage_status enum' do
    it 'rejects an unknown triage_status' do
      review = Review.new(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1,
                          triage_status: 'whatever')
      review.valid?
      expect(review.errors[:triage_status].join).to match(/included in the list/i)
    end

    it 'accepts every value in TRIAGE_STATUSES' do
      Review::TRIAGE_STATUSES.each do |status|
        review = Review.new(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1,
                            triage_status: status)
        review.valid?
        expect(review.errors[:triage_status]).to be_empty, "rejected: #{status}"
      end
    end
  end

  describe 'section enum' do
    it 'rejects an unknown section' do
      review = Review.new(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1,
                          section: 'whatever')
      review.valid?
      expect(review.errors[:section].join).to match(/recognized section/i)
    end

    it 'accepts NULL (general comment)' do
      review = Review.new(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1,
                          section: nil)
      review.valid?
      expect(review.errors[:section]).to be_empty
    end

    it 'accepts every key in SECTION_KEYS' do
      Review::SECTION_KEYS.each do |key|
        review = Review.new(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1,
                            section: key)
        review.valid?
        expect(review.errors[:section]).to be_empty, "rejected: #{key}"
      end
    end
  end

  describe 'duplicate_of_review_id invariants' do
    let!(:original) do
      Review.create!(action: 'comment', comment: 'original', user: @p_viewer, rule: @p1r1)
    end

    it 'requires a target when triage_status is duplicate' do
      review = Review.new(action: 'comment', comment: 'dup', user: @p_viewer, rule: @p1r1,
                          triage_status: 'duplicate', duplicate_of_review_id: nil)
      review.valid?
      expect(review.errors[:duplicate_of_review_id].join).to match(/required/i)
    end

    it 'rejects self-referencing duplicate' do
      review = Review.create!(action: 'comment', comment: 'dup', user: @p_viewer, rule: @p1r1)
      review.update(triage_status: 'duplicate', duplicate_of_review_id: review.id)
      expect(review.errors[:duplicate_of_review_id].join).to match(/cannot reference itself/i)
    end

    # PR #717 Task 24 — chained-duplicate guard. The triager must point at the
    # ultimate canonical, not at a comment that is itself a duplicate. Otherwise
    # the disposition matrix has multiple coalescing targets per logical issue.
    it 'rejects pointing duplicate_of at a comment that is itself a duplicate' do
      already_dup = Review.create!(action: 'comment', comment: 'A', user: @p_viewer, rule: @p1r1,
                                   triage_status: 'duplicate', duplicate_of_review_id: original.id)
      chained = Review.new(action: 'comment', comment: 'B', user: @p_viewer, rule: @p1r1,
                           triage_status: 'duplicate', duplicate_of_review_id: already_dup.id)
      expect(chained).not_to be_valid
      expect(chained.errors[:duplicate_of_review_id].join).to match(/ultimate canonical|another duplicate/i)
    end

    it 'allows duplicate_of pointing at a non-duplicate canonical' do
      new_dup = Review.new(action: 'comment', comment: 'C', user: @p_viewer, rule: @p1r1,
                           triage_status: 'duplicate', duplicate_of_review_id: original.id)
      expect(new_dup).to be_valid
    end

    # PR-717 review remediation .21 — duplicate_of_review_id only makes
    # sense when triage_status='duplicate'. Catches the opposite of
    # duplicate_status_requires_target — a stray cross-link on a non-
    # duplicate triage that would silently corrupt the disposition matrix.
    it 'rejects a stray duplicate_of_review_id on a non-duplicate triage' do
      review = Review.new(action: 'comment', comment: 'stray', user: @p_viewer, rule: @p1r1,
                          triage_status: 'concur', duplicate_of_review_id: original.id)
      expect(review).not_to be_valid
      expect(review.errors[:duplicate_of_review_id].join).to match(/blank.*not duplicate/i)
    end

    it 'allows nil duplicate_of_review_id on a non-duplicate triage' do
      review = Review.new(action: 'comment', comment: 'fine', user: @p_viewer, rule: @p1r1,
                          triage_status: 'concur', duplicate_of_review_id: nil)
      expect(review).to be_valid
    end
  end

  describe 'responding_to_review_id invariants' do
    let!(:parent) do
      Review.create!(action: 'comment', comment: 'parent', user: @p_viewer, rule: @p1r1)
    end

    it 'rejects self-referencing reply' do
      response = Review.create!(action: 'comment', comment: 'reply', user: @p_admin, rule: @p1r1)
      response.update(responding_to_review_id: response.id)
      expect(response.errors[:responding_to_review_id].join).to match(/cannot reference itself/i)
    end

    it 'links a reply via responding_to_review_id' do
      response = Review.create!(action: 'comment', comment: 'reply', user: @p_admin, rule: @p1r1,
                                responding_to_review_id: parent.id)
      expect(parent.reload.responses).to include(response)
    end

    it 'cascade-deletes responses when parent is deleted' do
      Review.create!(action: 'comment', comment: 'reply', user: @p_admin, rule: @p1r1,
                     responding_to_review_id: parent.id)
      expect { parent.destroy }.to change(Review, :count).by(-2)
    end
  end

  describe 'auto-set adjudicated_at on terminal triage statuses' do
    %w[duplicate informational withdrawn].each do |status|
      it "sets adjudicated_at when triage_status becomes #{status}" do
        review = Review.create!(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1)
        original_dup = Review.create!(action: 'comment', comment: 'orig', user: @p_viewer, rule: @p1r1)

        attrs = { triage_status: status, triage_set_by_id: @p_admin.id, triage_set_at: Time.current }
        attrs[:duplicate_of_review_id] = original_dup.id if status == 'duplicate'

        expect { review.update!(attrs) }
          .to change { review.reload.adjudicated_at }.from(nil).to(an_instance_of(ActiveSupport::TimeWithZone))
      end
    end
  end

  # PR #717 Task 30 — section is editable post-creation; the change must show up
  # in the audit log so the disposition record reflects who retagged what + why.
  describe 'section auditing' do
    let!(:section_review) do
      Review.create!(rule: @p1r1, user: @p_viewer, action: 'comment',
                     comment: 'misclassified', triage_status: 'pending',
                     section: nil)
    end

    it 'records an audit entry when section changes' do
      expect do
        section_review.audit_comment = 'tagging as Check after triager review'
        section_review.update!(section: 'check_content')
      end.to change { section_review.audits.count }.by_at_least(1)
    end

    it 'captures the from→to transition in audited_changes' do
      section_review.audit_comment = 'tagging as Check'
      section_review.update!(section: 'check_content')
      latest = section_review.audits.last
      expect(latest.audited_changes['section']).to eq([nil, 'check_content'])
    end

    it 'preserves the audit comment' do
      section_review.audit_comment = 'tagging as Check after triager review'
      section_review.update!(section: 'check_content')
      expect(section_review.audits.last.comment).to include('Check after triager')
    end
  end

  # PR-717 review remediation .7 — vulcan_audited needs associated_with: :rule
  # so audit rows survive admin_destroy as queryable records (auditable_id
  # points to a destroyed Review, but associated_id still points to a valid
  # Rule). All other audited models declare associated_with; Review was the gap.
  # Note: Rule is STI under BaseRule, so audited stores the polymorphic type
  # as the base class name 'BaseRule' but the polymorphic relation still
  # resolves to a Rule instance through STI.
  describe 'audit-trail association via associated_with: :rule' do
    let!(:assoc_review) do
      Review.create!(rule: @p1r1, user: @p_viewer, action: 'comment',
                     comment: 'something', triage_status: 'pending')
    end

    it 'populates associated to the rule on a triage update audit' do
      assoc_review.audit_comment = 'first triage'
      assoc_review.update!(triage_status: 'concur')
      latest = assoc_review.audits.last
      expect(latest.associated_type).to eq('BaseRule')
      expect(latest.associated_id).to eq(@p1r1.id)
    end

    it 'populates associated on the create-time audit row' do
      first_audit = assoc_review.audits.first
      expect(first_audit.associated_type).to eq('BaseRule')
      expect(first_audit.associated_id).to eq(@p1r1.id)
    end

    it 'allows querying rule-scoped audit history independent of auditable' do
      assoc_review.audit_comment = 'note'
      assoc_review.update!(triage_status: 'concur')
      rule_audits = Audited::Audit.where(associated_type: 'BaseRule', associated_id: @p1r1.id)
      expect(rule_audits.where(auditable_type: 'Review', auditable_id: assoc_review.id)).to exist
    end
  end

  describe 'withdrawn auto-sets adjudicated_by_id to commenter' do
    it 'sets adjudicated_by_id to user_id (the commenter themselves)' do
      review = Review.create!(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1)
      review.update!(triage_status: 'withdrawn')
      expect(review.reload.adjudicated_by_id).to eq(@p_viewer.id)
    end
  end

  describe 'scopes' do
    before do
      @c1 = Review.create!(action: 'comment', comment: 'one', user: @p_viewer, rule: @p1r1,
                           triage_status: 'pending')
      @c2 = Review.create!(action: 'comment', comment: 'two', user: @p_viewer, rule: @p1r1,
                           triage_status: 'concur', triage_set_by_id: @p_admin.id, triage_set_at: Time.current)
      @reply = Review.create!(action: 'comment', comment: 'reply', user: @p_admin, rule: @p1r1,
                              responding_to_review_id: @c1.id)
    end

    it 'top_level_comments excludes responses' do
      expect(Review.top_level_comments.where(rule: @p1r1)).to include(@c1, @c2)
      expect(Review.top_level_comments.where(rule: @p1r1)).not_to include(@reply)
    end

    it 'pending_triage returns only pending top-level comments' do
      expect(Review.pending_triage.where(rule: @p1r1)).to include(@c1)
      expect(Review.pending_triage.where(rule: @p1r1)).not_to include(@c2, @reply)
    end

    # PR-717 review remediation .1 — the original lifecycle migration set
    # triage_status NOT NULL DEFAULT 'pending'. On systems with pre-PR-717
    # `comment` reviews (action='comment' rows that were never part of a
    # public-comment workflow), every legacy row dumps into the triage
    # queue as "pending". DISA reviewers see unrelated historical content.
    # Fix: drop the DB default, allow NULL on the column, backfill legacy
    # rows (rows on rules in components that never opened a public-comment
    # period) to NULL. The pending_triage scope already filters by
    # `triage_status: 'pending'` (Rails treats NULL ≠ 'pending'), so the
    # behavior change is data-only — but we add a defensive
    # `where.not(triage_status: nil)` clause for explicit intent.
    context 'with legacy reviews (NULL triage_status)' do
      let!(:legacy_comment) do
        review = Review.create!(action: 'comment', comment: 'legacy', user: @p_viewer, rule: @p1r1,
                                triage_status: 'pending')
        # Simulate the legacy state directly. update_columns bypasses
        # validators + callbacks; the DB-level NOT NULL constraint must
        # be dropped by the migration before this can succeed.
        review.update_columns(triage_status: nil)
        review
      end

      it 'pending_triage excludes legacy comments with NULL triage_status' do
        expect(Review.pending_triage.where(rule: @p1r1)).not_to include(legacy_comment)
      end

      it 'allows NULL on triage_status at the DB layer' do
        # Reload to confirm the value persisted; would raise
        # ActiveRecord::StatementInvalid (NotNullViolation) on update_columns
        # in the legacy_comment let! if the column were still NOT NULL.
        expect(legacy_comment.reload.triage_status).to be_nil
      end

      it 'passes validation with triage_status nil' do
        # Without allow_nil on the inclusion validator, save would fail
        # with "Triage status is not included in the list" once a code
        # path tries to validate a NULL row (e.g. update through the model
        # with a different attribute).
        legacy_comment.reload
        expect(legacy_comment).to be_valid
      end
    end
  end

  describe 'audits' do
    it 'audits triage_status changes' do
      review = Review.create!(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1)
      expect do
        review.update!(triage_status: 'concur', triage_set_by_id: @p_admin.id, triage_set_at: Time.current)
      end.to change(review.audits, :count).by(1)
      audit = review.audits.last
      expect(audit.audited_changes['triage_status']).to eq(%w[pending concur])
    end
  end

  # PR-717 review remediation .4 step 4 — snapshot serialization for
  # the admin_destroy Component-level audit row. Captures full pre-
  # destroy state (full comment, every audited + lifecycle column,
  # ISO8601 timestamps so YAML safe-load doesn't break on Audit#find).
  describe '#snapshot_attributes' do
    let!(:snap_review) do
      Review.create!(action: 'comment', comment: 'snap content', user: @p_viewer, rule: @p1r1,
                     section: 'check_content',
                     triage_status: 'concur',
                     triage_set_by_id: @p_admin.id,
                     triage_set_at: Time.zone.parse('2026-04-01T10:00:00Z'),
                     adjudicated_at: Time.zone.parse('2026-04-02T11:00:00Z'),
                     adjudicated_by_id: @p_admin.id)
    end

    it 'returns a hash with every audited + lifecycle + imported_attribution column' do
      h = snap_review.snapshot_attributes
      %w[id user_id rule_id action comment section triage_status
         triage_set_by_id triage_set_at adjudicated_at adjudicated_by_id
         duplicate_of_review_id responding_to_review_id
         triage_set_by_imported_email triage_set_by_imported_name
         adjudicated_by_imported_email adjudicated_by_imported_name
         created_at updated_at].each do |col|
        expect(h).to have_key(col)
      end
    end

    it 'preserves the FULL comment text (not truncated)' do
      long = 'x' * 3000
      snap_review.update!(comment: long)
      expect(snap_review.snapshot_attributes['comment']).to eq(long)
    end

    it 'serializes timestamps as ISO8601 strings (not Time objects)' do
      h = snap_review.snapshot_attributes
      expect(h['triage_set_at']).to be_a(String)
      expect(h['triage_set_at']).to match(/\AZ?\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      expect(h['adjudicated_at']).to be_a(String)
      expect(h['created_at']).to be_a(String)
      expect(h['updated_at']).to be_a(String)
    end

    it 'returns nil for unset nullable fields, not empty strings' do
      bare = Review.create!(action: 'comment', comment: 'bare', user: @p_viewer, rule: @p1r1)
      h = bare.snapshot_attributes
      expect(h['triage_set_by_id']).to be_nil
      expect(h['adjudicated_at']).to be_nil
      expect(h['triage_set_by_imported_email']).to be_nil
    end
  end

  # PR-717 review remediation .4 step 2 — SQL CTE scope for the
  # snapshot-capture step in admin_destroy. Returns root + every
  # descendant via responding_to_review_id chain, in deterministic
  # depth-first-ish order so the audit-row snapshot is reproducible.
  describe '.subtree_with_ancestry' do
    let!(:root) do
      Review.create!(action: 'comment', comment: 'root', user: @p_viewer, rule: @p1r1)
    end
    let!(:child_a) do
      Review.create!(action: 'comment', comment: 'child A', user: @p_viewer, rule: @p1r1,
                     responding_to_review_id: root.id)
    end
    let!(:child_b) do
      Review.create!(action: 'comment', comment: 'child B', user: @p_viewer, rule: @p1r1,
                     responding_to_review_id: root.id)
    end
    let!(:grandchild) do
      Review.create!(action: 'comment', comment: 'grandchild of A', user: @p_viewer, rule: @p1r1,
                     responding_to_review_id: child_a.id)
    end

    it 'returns the root and every descendant' do
      ids = Review.subtree_with_ancestry(root.id).map(&:id)
      expect(ids).to contain_exactly(root.id, child_a.id, child_b.id, grandchild.id)
    end

    it 'returns just the root when there are no replies' do
      lone = Review.create!(action: 'comment', comment: 'lone', user: @p_viewer, rule: @p1r1)
      expect(Review.subtree_with_ancestry(lone.id).map(&:id)).to eq([lone.id])
    end

    it 'returns deterministic order: root first, then by parent_id NULLS FIRST, created_at' do
      ids = Review.subtree_with_ancestry(root.id).map(&:id)
      # root is first (parent_id is nil within the subtree-as-roots framing)
      expect(ids.first).to eq(root.id)
      # grandchild MUST come after its parent child_a (depth ordering)
      expect(ids.index(grandchild.id)).to be > ids.index(child_a.id)
    end

    it 'returns nothing when the root id does not exist' do
      expect(Review.subtree_with_ancestry(0)).to be_empty
    end

    it 'is an ActiveRecord::Relation of Review records (not raw rows)' do
      result = Review.subtree_with_ancestry(root.id)
      expect(result.first).to be_a(Review)
      # Has access to associations, not just attributes
      expect(result.first.user).to eq(@p_viewer)
    end
  end

  # PR-717 review remediation .j4a step A1 — `reviews` table needs two
  # nullable string columns to preserve original commenter attribution
  # when the User row gets removed (User#destroy → reviews.user_id NULL
  # via on_delete: :nullify FK in step A3) or when a json_archive import
  # carries a commenter email/name that doesn't resolve to a User on the
  # target instance. Mirrors the `_imported_email/_name` columns added in
  # `.8` for triage_set_by + adjudicated_by.
  describe 'commenter_imported_* columns (PR-717 .j4a step A1)' do
    it 'has commenter_imported_email column' do
      expect(Review.column_names).to include('commenter_imported_email')
    end

    it 'has commenter_imported_name column' do
      expect(Review.column_names).to include('commenter_imported_name')
    end

    it 'persists commenter_imported_email + commenter_imported_name values' do
      review = Review.create!(action: 'comment', comment: 'c', user: @p_viewer,
                              rule: @p1r1, triage_status: 'pending')
      review.update_columns(commenter_imported_email: 'imp@old.example',
                            commenter_imported_name: 'Imported Person')
      review.reload
      expect(review.commenter_imported_email).to eq('imp@old.example')
      expect(review.commenter_imported_name).to eq('Imported Person')
    end
  end

  describe 'attribution display helpers (PR-717 .8 imported attribution)' do
    let(:base) do
      Review.create!(action: 'comment', comment: 'c', user: @p_viewer, rule: @p1r1, triage_status: 'pending')
    end

    describe '#triager_display_name' do
      it 'returns the resolved User name when FK is set' do
        base.update_columns(triage_set_by_id: @p_admin.id, triage_set_at: Time.current)
        expect(base.reload.triager_display_name).to eq(@p_admin.name)
      end

      it 'falls back to imported_name when FK is nil' do
        base.update_columns(triage_set_by_imported_name: 'Alice Imported',
                            triage_set_by_imported_email: 'alice@old.example')
        expect(base.reload.triager_display_name).to eq('Alice Imported')
      end

      it 'falls back to imported_email when imported_name is blank' do
        base.update_columns(triage_set_by_imported_name: nil,
                            triage_set_by_imported_email: 'bob@old.example')
        expect(base.reload.triager_display_name).to eq('bob@old.example')
      end

      it 'returns nil when nothing is set' do
        expect(base.triager_display_name).to be_nil
      end
    end

    describe '#triager_imported?' do
      it 'is false when FK is set (resolved User)' do
        base.update_columns(triage_set_by_id: @p_admin.id, triage_set_at: Time.current)
        expect(base.reload.triager_imported?).to be(false)
      end

      it 'is true when FK is nil and imported attribution is present' do
        base.update_columns(triage_set_by_imported_name: 'Alice')
        expect(base.reload.triager_imported?).to be(true)
      end

      it 'is false when FK is nil and no imported attribution' do
        expect(base.triager_imported?).to be(false)
      end
    end

    describe '#adjudicator_display_name' do
      it 'returns the resolved User name when FK is set' do
        base.update_columns(adjudicated_by_id: @p_admin.id, adjudicated_at: Time.current)
        expect(base.reload.adjudicator_display_name).to eq(@p_admin.name)
      end

      it 'falls back to imported_name when FK is nil' do
        base.update_columns(adjudicated_by_imported_name: 'Carol Imported',
                            adjudicated_by_imported_email: 'carol@old.example')
        expect(base.reload.adjudicator_display_name).to eq('Carol Imported')
      end

      it 'falls back to imported_email when imported_name blank' do
        base.update_columns(adjudicated_by_imported_email: 'dan@old.example')
        expect(base.reload.adjudicator_display_name).to eq('dan@old.example')
      end

      it 'returns nil when nothing is set' do
        expect(base.adjudicator_display_name).to be_nil
      end
    end

    describe '#adjudicator_imported?' do
      it 'is false when FK is set' do
        base.update_columns(adjudicated_by_id: @p_admin.id, adjudicated_at: Time.current)
        expect(base.reload.adjudicator_imported?).to be(false)
      end

      it 'is true when FK is nil and imported attribution is present' do
        base.update_columns(adjudicated_by_imported_email: 'dan@old.example')
        expect(base.reload.adjudicator_imported?).to be(true)
      end

      it 'is false when FK is nil and no imported attribution' do
        expect(base.adjudicator_imported?).to be(false)
      end
    end
  end
end
