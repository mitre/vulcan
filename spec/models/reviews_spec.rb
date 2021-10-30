# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review, type: :model do
  before :each do
    srg_xml = file_fixture('U_Web_Server_V2R3_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    # Create projects
    @p1 = Project.create(name: 'P1')
    @p2 = Project.create(name: 'P2')

    # Create Users
    @admin = create(:user, admin: true)
    @p_admin = build(:user)
    @p_reviewer = build(:user)
    @p_author = build(:user)
    @other_p_admin = build(:user)

    # Give users project roles
    Membership.create(user: @p_admin, membership: @p1, role: 'admin')
    Membership.create(user: @p_reviewer, membership: @p1, role: 'reviewer')
    Membership.create(user: @p_author, membership: @p1, role: 'author')
    Membership.create(user: @other_p_admin, membership: @p2, role: 'admin')

    # Create a component
    @p1_c1 = Component.create!(project: @p1, version: 'Photon OS 3 V1R1', prefix: 'PHOS-03', based_on: srg)

    # Create rules
    @p1r1 = Rule.create(
      component: @p1_c1,
      rule_id: 'P1-R1',
      status: 'Applicable - Configurable',
      rule_severity: 'medium',
      srg_rule: srg.srg_rules.first
    )
  end

  context 'failed take review action' do
    it 'does not take action for invalid review' do
      # Sanity check on initial state
      expect(@p1r1.review_requestor_id).to eq(nil)
      expect(@p1r1.locked).to eq(false)

      # Do something we can't do right now
      review = Review.new(action: 'approve', comment: '...', user: @p_admin, rule: @p1r1)

      expect(review.save).to eq(false)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to eq(nil)
      expect(@p1r1.locked).to eq(false)
    end

    it 'does not save if rule fails to save' do
      # Change a non-review field with the subsequent review fields
      @p1r1.status = '...'

      # Sanity check on initial state
      expect(@p1r1.review_requestor_id).to eq(nil)
      expect(@p1r1.locked).to eq(false)

      review = Review.new(action: 'request_review', comment: '...', user: @p_admin, rule: @p1r1)
      expect(review.save).to eq(false)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to eq(nil)
      expect(@p1r1.locked).to eq(false)
    end
  end

  context 'sucessful take review action' do
    it 'takes no action on comment' do
      expect(@p1r1.review_requestor_id).to eq(nil)
      expect(@p1r1.locked).to eq(false)
      Review.create(action: 'comment', comment: '...', user: @p_admin, rule: @p1r1)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to eq(nil)
      expect(@p1r1.locked).to eq(false)
    end

    it 'take action on request_review' do
      Review.create(action: 'request_review', comment: '...', user: @p_admin, rule: @p1r1)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to eq(@p_admin.id)
      expect(@p1r1.locked).to eq(false)
    end

    it 'take action on revoke_review_request' do
      @p1r1.update(review_requestor: @p_admin)
      Review.create(action: 'revoke_review_request', comment: '...', user: @p_admin, rule: @p1r1)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to eq(nil)
      expect(@p1r1.locked).to eq(false)
    end

    it 'take action on request_changes' do
      @p1r1.update(review_requestor: @p_admin)
      Review.create(action: 'request_changes', comment: '...', user: @p_admin, rule: @p1r1)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to eq(nil)
      expect(@p1r1.locked).to eq(false)
    end

    it 'take action on approve' do
      @p1r1.update(review_requestor: @p_admin)
      Review.create(action: 'approve', comment: '...', user: @p_admin, rule: @p1r1)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to eq(nil)
      expect(@p1r1.locked).to eq(true)
    end

    it 'take action on lock_control' do
      Review.create(action: 'lock_control', comment: '...', user: @p_admin, rule: @p1r1)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to eq(nil)
      expect(@p1r1.locked).to eq(true)
    end

    it 'take action on unlock_control' do
      @p1r1.update(locked: true)
      Review.create(action: 'unlock_control', comment: '...', user: @p_admin, rule: @p1r1)
      @p1r1.reload
      expect(@p1r1.review_requestor_id).to eq(nil)
      expect(@p1r1.locked).to eq(false)
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
    it 'allows any member to comment' do
      [
        @admin,
        @p_admin,
        @p_reviewer,
        @p_author
      ].each do |user|
        review = Review.new(action: 'comment', comment: '...', user: user, rule: @p1r1)
        # review.valid?
        expect(review).to be_valid
      end
    end
  end
end
