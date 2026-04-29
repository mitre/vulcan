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
end
