# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review do
  include_context 'reviews model base setup'

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
        review = Review.new(action: action, comment: '...', user: reviews_other_p_admin, rule: reviews_rule)
        review.valid?
        expect(review.errors[:base]).to include('You have no permissions on this project')
      end
    end

    it 'blocks request_review when rule is locked' do
      reviews_rule.update(locked: true)
      review = Review.new(action: 'request_review', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Cannot request a review on a locked control')
    end

    it 'blocks request_review when rule is already under review' do
      reviews_rule.update(review_requestor: reviews_p_author)
      review = Review.new(action: 'request_review', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Control is already under review')
    end

    it 'blocks revoke_review_request when rule is not under review' do
      review = Review.new(action: 'revoke_review_request', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Control is not currently under review')
    end

    it 'blocks revoke_review_request when not admin or review requestor' do
      reviews_rule.update(review_requestor: reviews_p_author)
      review = Review.new(action: 'revoke_review_request', comment: '...', user: reviews_p_reviewer, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Only the requestor or an admin can revoke a review request')

      review.user = reviews_admin
      expect(review).to be_valid

      review.user = reviews_p_admin
      expect(review).to be_valid

      review.user = reviews_p_author
      expect(review).to be_valid
    end

    it 'blocks request_changes when rule is not under review' do
      reviews_rule.update(locked: true)
      review = Review.new(action: 'request_changes', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Control is not currently under review')
    end

    it 'blocks request_changes when not admin or reviewer' do
      reviews_rule.update(review_requestor: reviews_p_author)
      review = Review.new(action: 'request_changes', comment: '...', user: reviews_p_author, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Only admins and reviewers can request changes')

      review.user = reviews_admin
      expect(review).to be_valid

      review.user = reviews_p_admin
      expect(review).to be_valid

      review.user = reviews_p_reviewer
      expect(review).to be_valid
    end

    it 'blocks request_changes when reviewer is the review requestor' do
      reviews_rule.update(review_requestor: reviews_p_reviewer)
      review = Review.new(action: 'request_changes', comment: '...', user: reviews_p_reviewer, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Reviewers cannot review their own review requests')
    end

    it 'blocks approve when control is not under review' do
      review = Review.new(action: 'approve', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Control is not currently under review')
    end

    it 'blocks approve when not admin or reviewer' do
      reviews_rule.update(review_requestor: reviews_p_author)
      review = Review.new(action: 'approve', comment: '...', user: reviews_p_author, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Only admins and reviewers can approve')

      review.user = reviews_admin
      expect(review).to be_valid

      review.user = reviews_p_admin
      expect(review).to be_valid

      review.user = reviews_p_reviewer
      expect(review).to be_valid
    end

    it 'blocks approve when reviewer is the review requestor' do
      reviews_rule.update(review_requestor: reviews_p_reviewer)
      review = Review.new(action: 'approve', comment: '...', user: reviews_p_reviewer, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Reviewers cannot review their own review requests')
    end

    it 'blocks lock_control when not admin' do
      review = Review.new(action: 'lock_control', comment: '...', user: reviews_p_author, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Only an admin can lock')

      review.user = reviews_p_reviewer
      review.valid?
      expect(review.errors[:base]).to include('Only an admin can lock')

      review.user = reviews_admin
      expect(review).to be_valid

      review.user = reviews_p_admin
      expect(review).to be_valid
    end

    it 'blocks lock_control when rule is under review' do
      reviews_rule.update(review_requestor: reviews_p_reviewer)
      review = Review.new(action: 'lock_control', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Cannot lock a control that is currently under review')
    end

    it 'blocks lock_control when rule is already locked' do
      reviews_rule.update(locked: true)
      review = Review.new(action: 'lock_control', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Control is already locked')
    end

    it 'blocks unlock_control when not admin' do
      reviews_rule.update(locked: true)
      review = Review.new(action: 'unlock_control', comment: '...', user: reviews_p_author, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Only an admin can unlock')

      review.user = reviews_p_reviewer
      review.valid?
      expect(review.errors[:base]).to include('Only an admin can unlock')

      review.user = reviews_admin
      expect(review).to be_valid

      review.user = reviews_p_admin
      expect(review).to be_valid
    end

    it 'blocks unlock_control when rule is under review' do
      reviews_rule.update(review_requestor: reviews_p_reviewer)
      review = Review.new(action: 'unlock_control', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Cannot unlock a control that is currently under review')
    end

    it 'blocks unlock_control when rule is already unlocked' do
      review = Review.new(action: 'unlock_control', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Control is already unlocked')
    end
  end

  context 'validations on valid reviews' do
    it 'allows any member, including viewers, to comment' do
      [
        reviews_admin,
        reviews_p_admin,
        reviews_p_reviewer,
        reviews_p_author,
        reviews_p_viewer
      ].each do |user|
        review = Review.new(action: 'comment', comment: '...', user: user, rule: reviews_rule)
        role = user.effective_permissions(reviews_rule.component) || 'site-admin'
        expect(review).to be_valid, "expected #{user} (membership role: #{role}) to be able to comment"
      end
    end
  end

  context 'action inclusion validation' do
    it 'rejects an unknown action string' do
      review = Review.new(action: 'definitely_not_a_real_action', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      expect(review).not_to be_valid
      expect(review.errors[:action].join).to match(/not a recognized review action/)
    end

    it 'accepts every action listed in Review::VALID_ACTIONS' do
      Review::VALID_ACTIONS.each do |action_name|
        review = Review.new(action: action_name, comment: '...', user: reviews_p_admin, rule: reviews_rule)
        review.valid?
        expect(review.errors[:action]).to be_empty,
                                          "action #{action_name.inspect} unexpectedly failed inclusion validator"
      end
    end
  end

  context 'viewer permission boundaries' do
    it 'rejects a viewer attempting to approve' do
      reviews_rule.update(review_requestor: reviews_p_author)
      review = Review.new(action: 'approve', comment: 'lgtm', user: reviews_p_viewer, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Only admins and reviewers can approve')
    end

    it 'rejects a viewer attempting to request_changes' do
      reviews_rule.update(review_requestor: reviews_p_author)
      review = Review.new(action: 'request_changes', comment: 'nope', user: reviews_p_viewer, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Only admins and reviewers can request changes')
    end

    it 'rejects a viewer attempting to lock_control' do
      review = Review.new(action: 'lock_control', comment: 'lock!', user: reviews_p_viewer, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Only an admin can lock')
    end

    it 'rejects a viewer attempting to request_review' do
      review = Review.new(action: 'request_review', comment: 'please look', user: reviews_p_viewer, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base]).to include('Only admins, reviewers, and authors can request a review')
    end
  end

  context 'ACTION_PERMISSIONS map (per-action role gate)' do
    it 'rejects a viewer attempting request_review' do
      review = Review.new(action: 'request_review', comment: 'try', user: reviews_p_viewer, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base].join).to match(/insufficient permissions to request_review/i)
    end

    it 'rejects a viewer attempting revoke_review_request' do
      reviews_rule.update(review_requestor: reviews_p_author)
      review = Review.new(action: 'revoke_review_request', comment: 'try', user: reviews_p_viewer, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base].join).to match(/insufficient permissions to revoke_review_request/i)
    end

    it 'rejects a viewer attempting request_changes via the role gate' do
      review = Review.new(action: 'request_changes', comment: 'try', user: reviews_p_viewer, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base].join).to match(/insufficient permissions to request_changes/i)
    end

    it 'rejects an author attempting approve via the role gate' do
      review = Review.new(action: 'approve', comment: 'lgtm', user: reviews_p_author, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base].join).to match(/insufficient permissions to approve/i)
    end

    it 'rejects an author attempting lock_control via the role gate' do
      review = Review.new(action: 'lock_control', comment: 'lock', user: reviews_p_author, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base].join).to match(/insufficient permissions to lock_control/i)
    end

    it 'allows a viewer to comment (the only mutating action they can perform)' do
      review = Review.new(action: 'comment', comment: 'looks good', user: reviews_p_viewer, rule: reviews_rule)
      review.valid?
      expect(review.errors[:base].grep(/insufficient permissions/i)).to be_empty
    end

    it 'allows an admin to perform every action (smoke check across the map)' do
      %w[comment request_review request_changes approve lock_control unlock_control].each do |action|
        review = Review.new(action: action, comment: 'x', user: reviews_p_admin, rule: reviews_rule)
        review.valid?
        perm_errors = review.errors[:base].grep(/insufficient permissions/i)
        expect(perm_errors).to be_empty,
                               "admin unexpectedly blocked from #{action}: #{perm_errors.inspect}"
      end
    end
  end

  context 'comment-action length cap' do
    it 'rejects a comment-action review longer than 4000 chars' do
      review = Review.new(action: 'comment', comment: 'x' * 4001, user: reviews_p_viewer, rule: reviews_rule)
      review.valid?
      expect(review.errors[:comment].join).to match(/too long/i)
    end

    it 'allows a comment-action review at exactly 4000 chars' do
      review = Review.new(action: 'comment', comment: 'x' * 4000, user: reviews_p_viewer, rule: reviews_rule)
      review.valid?
      expect(review.errors[:comment]).to be_empty
    end

    it 'allows other actions up to the configured input_limits.review_comment' do
      long_text = 'x' * 4500
      reviews_rule.update(review_requestor: reviews_p_author)
      review = Review.new(action: 'request_changes', comment: long_text, user: reviews_p_admin, rule: reviews_rule)
      review.valid?
      expect(review.errors[:comment]).to be_empty
    end
  end
end
