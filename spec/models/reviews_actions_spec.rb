# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review do
  include_context 'reviews model base setup'

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
end
