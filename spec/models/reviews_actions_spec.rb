# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review do
  include_context 'reviews model base setup'

  context 'failed take review action' do
    it 'does not take action for invalid review' do
      # Sanity check on initial state
      expect(reviews_rule.review_requestor_id).to be_nil
      expect(reviews_rule.locked).to be(false)

      # Do something we can't do right now
      review = Review.new(action: 'approve', comment: '...', user: reviews_p_admin, rule: reviews_rule)

      expect(review.save).to be(false)
      reviews_rule.reload
      expect(reviews_rule.review_requestor_id).to be_nil
      expect(reviews_rule.locked).to be(false)
    end

    it 'does not save if rule fails to save' do
      # Change a non-review field with the subsequent review fields
      reviews_rule.status = '...'

      # Sanity check on initial state
      expect(reviews_rule.review_requestor_id).to be_nil
      expect(reviews_rule.locked).to be(false)

      review = Review.new(action: 'request_review', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      expect(review.save).to be(false)
      reviews_rule.reload
      expect(reviews_rule.review_requestor_id).to be_nil
      expect(reviews_rule.locked).to be(false)
    end
  end

  context 'sucessful take review action' do
    it 'takes no action on comment' do
      expect(reviews_rule.review_requestor_id).to be_nil
      expect(reviews_rule.locked).to be(false)
      Review.create(action: 'comment', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      reviews_rule.reload
      expect(reviews_rule.review_requestor_id).to be_nil
      expect(reviews_rule.locked).to be(false)
    end

    it 'take action on request_review' do
      Review.create(action: 'request_review', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      reviews_rule.reload
      expect(reviews_rule.review_requestor_id).to eq(reviews_p_admin.id)
      expect(reviews_rule.locked).to be(false)
    end

    it 'take action on revoke_review_request' do
      reviews_rule.update(review_requestor: reviews_p_admin)
      Review.create(action: 'revoke_review_request', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      reviews_rule.reload
      expect(reviews_rule.review_requestor_id).to be_nil
      expect(reviews_rule.locked).to be(false)
    end

    it 'take action on request_changes' do
      reviews_rule.update(review_requestor: reviews_p_admin)
      Review.create(action: 'request_changes', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      reviews_rule.reload
      expect(reviews_rule.review_requestor_id).to be_nil
      expect(reviews_rule.locked).to be(false)
    end

    it 'take action on approve' do
      reviews_rule.update(review_requestor: reviews_p_admin)
      Review.create(action: 'approve', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      reviews_rule.reload
      expect(reviews_rule.review_requestor_id).to be_nil
      expect(reviews_rule.locked).to be(true)
    end

    it 'take action on lock_control' do
      Review.create(action: 'lock_control', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      reviews_rule.reload
      expect(reviews_rule.review_requestor_id).to be_nil
      expect(reviews_rule.locked).to be(true)
    end

    it 'take action on unlock_control' do
      reviews_rule.update(locked: true)
      Review.create(action: 'unlock_control', comment: '...', user: reviews_p_admin, rule: reviews_rule)
      reviews_rule.reload
      expect(reviews_rule.review_requestor_id).to be_nil
      expect(reviews_rule.locked).to be(false)
    end
  end
end
