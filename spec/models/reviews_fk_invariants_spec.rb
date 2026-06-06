# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review do
  include_context 'reviews model base setup'

  describe 'duplicate_of_review_id invariants' do
    let!(:original) do
      create(:review, :comment, comment: 'original', section: nil, user: reviews_p_viewer, rule: reviews_rule)
    end

    it 'requires a target when triage_status is duplicate' do
      review = Review.new(action: 'comment', comment: 'dup', user: reviews_p_viewer, rule: reviews_rule,
                          triage_status: 'duplicate', duplicate_of_review_id: nil)
      review.valid?
      expect(review.errors[:duplicate_of_review_id].join).to match(/required/i)
    end

    it 'rejects self-referencing duplicate' do
      review = create(:review, :comment, comment: 'dup', section: nil, user: reviews_p_viewer, rule: reviews_rule)
      review.update(triage_status: 'duplicate', duplicate_of_review_id: review.id)
      expect(review.errors[:duplicate_of_review_id].join).to match(/cannot reference itself/i)
    end

    # chained-duplicate guard. The triager must point at the
    # ultimate canonical, not at a comment that is itself a duplicate. Otherwise
    # the disposition matrix has multiple coalescing targets per logical issue.
    it 'rejects pointing duplicate_of at a comment that is itself a duplicate' do
      already_dup = create(:review, :comment, comment: 'A', section: nil, user: reviews_p_viewer, rule: reviews_rule,
                                              triage_status: 'duplicate', duplicate_of_review_id: original.id)
      chained = Review.new(action: 'comment', comment: 'B', user: reviews_p_viewer, rule: reviews_rule,
                           triage_status: 'duplicate', duplicate_of_review_id: already_dup.id)
      expect(chained).not_to be_valid
      expect(chained.errors[:duplicate_of_review_id].join).to match(/ultimate canonical|another duplicate/i)
    end

    it 'allows duplicate_of pointing at a non-duplicate canonical' do
      new_dup = Review.new(action: 'comment', comment: 'C', user: reviews_p_viewer, rule: reviews_rule,
                           triage_status: 'duplicate', duplicate_of_review_id: original.id)
      expect(new_dup).to be_valid
    end

    # duplicate_of_review_id only makes
    # sense when triage_status='duplicate'. Catches the opposite of
    # duplicate_status_requires_target — a stray cross-link on a non-
    # duplicate triage that would silently corrupt the disposition matrix.
    it 'defensive callback clears stray duplicate_of_review_id on a non-duplicate triage' do
      review = Review.new(action: 'comment', comment: 'stray', user: reviews_p_viewer, rule: reviews_rule,
                          triage_status: 'concur', duplicate_of_review_id: original.id)
      review.valid?
      expect(review.duplicate_of_review_id).to be_nil
    end

    it 'allows nil duplicate_of_review_id on a non-duplicate triage' do
      review = Review.new(action: 'comment', comment: 'fine', user: reviews_p_viewer, rule: reviews_rule,
                          triage_status: 'concur', duplicate_of_review_id: nil)
      expect(review).to be_valid
    end
  end

  describe 'addressed_by_rule_id invariants' do
    let!(:parent_rule) do
      Rule.create(component: reviews_component, rule_id: 'P1-R2', status: 'Applicable - Configurable',
                  rule_severity: 'medium', srg_rule: reviews_srg.srg_rules.second)
    end

    it 'requires addressed_by_rule_id when triage_status is addressed_by' do
      review = Review.new(action: 'comment', comment: 'child comment', user: reviews_p_viewer, rule: reviews_rule,
                          triage_status: 'addressed_by', addressed_by_rule_id: nil)
      expect(review).not_to be_valid
      expect(review.errors[:addressed_by_rule_id].join).to match(/required/i)
    end

    it 'accepts addressed_by with a valid rule reference' do
      review = Review.new(action: 'comment', comment: 'child comment', user: reviews_p_viewer, rule: reviews_rule,
                          triage_status: 'addressed_by', addressed_by_rule_id: parent_rule.id)
      review.valid?
      expect(review.errors[:addressed_by_rule_id]).to be_empty
    end

    it 'defensive callback clears stray addressed_by_rule_id on a non-addressed_by triage' do
      review = Review.new(action: 'comment', comment: 'x', user: reviews_p_viewer, rule: reviews_rule,
                          triage_status: 'concur', addressed_by_rule_id: parent_rule.id)
      review.valid?
      expect(review.addressed_by_rule_id).to be_nil
    end

    it 'allows nil addressed_by_rule_id on a non-addressed_by triage' do
      review = Review.new(action: 'comment', comment: 'fine', user: reviews_p_viewer, rule: reviews_rule,
                          triage_status: 'concur', addressed_by_rule_id: nil)
      expect(review).to be_valid
    end

    it 'auto-adjudicates addressed_by as a terminal status' do
      review = create(:review, :comment, comment: 'child comment', section: nil, user: reviews_p_viewer, rule: reviews_rule)
      review.update!(
        triage_status: 'addressed_by',
        addressed_by_rule_id: parent_rule.id,
        triage_set_by_id: reviews_p_admin.id,
        triage_set_at: Time.current
      )
      expect(review.reload.adjudicated_at).to be_present
    end

    it 'exposes the addressed_by association' do
      review = create(:review, :comment, comment: 'child comment', section: nil, user: reviews_p_viewer, rule: reviews_rule)
      review.update!(
        triage_status: 'addressed_by',
        addressed_by_rule_id: parent_rule.id,
        triage_set_by_id: reviews_p_admin.id,
        triage_set_at: Time.current
      )
      expect(review.reload.addressed_by_rule).to eq(parent_rule)
    end
  end

  describe 'responding_to_review_id invariants' do
    let!(:parent) do
      create(:review, :comment, comment: 'parent', section: nil, user: reviews_p_viewer, rule: reviews_rule)
    end

    it 'rejects self-referencing reply' do
      response = create(:review, :comment, comment: 'reply', section: nil, user: reviews_p_admin, rule: reviews_rule)
      response.update(responding_to_review_id: response.id)
      expect(response.errors[:responding_to_review_id].join).to match(/cannot reference itself/i)
    end

    it 'links a reply via responding_to_review_id' do
      response = create(:review, :comment, comment: 'reply', section: nil, user: reviews_p_admin, rule: reviews_rule,
                                           responding_to_review_id: parent.id)
      expect(parent.reload.responses).to include(response)
    end

    it 'cascade-deletes responses when parent is deleted' do
      create(:review, :comment, comment: 'reply', section: nil, user: reviews_p_admin, rule: reviews_rule,
                                responding_to_review_id: parent.id)
      expect { parent.destroy }.to change(Review, :count).by(-2)
    end

    # Defense-in-depth: replies are conversation, not adjudicable.
    # The triage queue filters by responding_to_review_id IS NULL, but a
    # future regression could leak triage_status onto a reply via mass-
    # assignment. The model validator stops it at save time.
    it 'rejects setting triage_status on a reply' do
      reply = Review.new(action: 'comment', comment: 'reply', user: reviews_p_admin, rule: reviews_rule,
                         responding_to_review_id: parent.id, triage_status: 'concur')
      expect(reply.valid?).to be(false)
      expect(reply.errors[:triage_status].join).to match(/cannot be set on a reply/i)
    end

    it 'allows nil triage_status on a reply (the default)' do
      reply = Review.new(action: 'comment', comment: 'reply', user: reviews_p_admin, rule: reviews_rule,
                         responding_to_review_id: parent.id)
      expect(reply.valid?).to be(true)
    end
  end
end
