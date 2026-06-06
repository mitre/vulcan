# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review do
  include_context 'reviews model base setup'

  describe 'triage_status enum' do
    it 'rejects an unknown triage_status' do
      review = Review.new(action: 'comment', comment: 'x', user: reviews_p_viewer, rule: reviews_rule,
                          triage_status: 'whatever')
      review.valid?
      expect(review.errors[:triage_status].join).to match(/included in the list/i)
    end

    it 'accepts every value in TRIAGE_STATUSES' do
      Review::TRIAGE_STATUSES.each do |status|
        review = Review.new(action: 'comment', comment: 'x', user: reviews_p_viewer, rule: reviews_rule,
                            triage_status: status)
        review.valid?
        expect(review.errors[:triage_status]).to be_empty, "rejected: #{status}"
      end
    end
  end

  describe 'section enum' do
    it 'rejects an unknown section' do
      review = Review.new(action: 'comment', comment: 'x', user: reviews_p_viewer, rule: reviews_rule,
                          section: 'whatever')
      review.valid?
      expect(review.errors[:section].join).to match(/recognized section/i)
    end

    it 'accepts NULL (general comment)' do
      review = Review.new(action: 'comment', comment: 'x', user: reviews_p_viewer, rule: reviews_rule,
                          section: nil)
      review.valid?
      expect(review.errors[:section]).to be_empty
    end

    it 'accepts every key in SECTION_KEYS' do
      Review::SECTION_KEYS.each do |key|
        review = Review.new(action: 'comment', comment: 'x', user: reviews_p_viewer, rule: reviews_rule,
                            section: key)
        review.valid?
        expect(review.errors[:section]).to be_empty, "rejected: #{key}"
      end
    end
  end

  describe 'parametric callback safety — all triage statuses' do
    let(:callback_user) { reviews_p_viewer }
    let(:callback_rule) { reviews_rule }
    let(:callback_triager) { reviews_p_admin }

    it_behaves_like 'clears stale FKs for all triage statuses'
    it_behaves_like 'auto-adjudicates only terminal statuses'

    it 'auto-adjudicates normally when save_intent is nil (default)' do
      review = create(:review, :comment, comment: 'nil intent', section: nil, user: reviews_p_viewer, rule: reviews_rule)
      expect(review.save_intent).to be_nil

      review.update!(triage_status: 'informational', triage_set_by_id: reviews_p_admin.id, triage_set_at: Time.current)
      review.reload
      expect(review.adjudicated_at).to be_present
    end
  end

  describe 'auto_set_adjudicated skips when adjudicated_at already present' do
    it 'does not overwrite explicit adjudicated_by_id with callback default' do
      review = create(:review, :comment, comment: 'x', section: nil, user: reviews_p_viewer, rule: reviews_rule)
      explicit_admin = reviews_p_admin

      review.update!(
        triage_status: 'withdrawn',
        adjudicated_at: Time.current,
        adjudicated_by_id: explicit_admin.id,
        triage_set_by_id: reviews_p_author.id,
        triage_set_at: Time.current
      )

      review.reload
      expect(review.adjudicated_by_id).to eq(explicit_admin.id)
    end
  end

  describe 'save_intent :reopen bypasses auto-adjudication on terminal statuses' do
    Review::TERMINAL_AUTO_ADJUDICATE_STATUSES.each do |status|
      it "does NOT re-set adjudicated_at when save_intent is :reopen for '#{status}'" do
        review = create(:review, :comment, comment: 'reopen test', section: nil,
                                           user: reviews_p_viewer, rule: reviews_rule)

        attrs = { triage_status: status, triage_set_by_id: reviews_p_admin.id, triage_set_at: Time.current }
        if status == 'duplicate'
          dup_target = create(:review, :comment, comment: 'dup target', section: nil,
                                                 user: reviews_p_viewer, rule: reviews_rule)
          attrs[:duplicate_of_review_id] = dup_target.id
        end
        attrs[:addressed_by_rule_id] = reviews_rule.id if status == 'addressed_by'

        review.update!(attrs)
        review.reload
        expect(review.adjudicated_at).to be_present

        review.save_intent = :reopen
        review.update!(adjudicated_at: nil, adjudicated_by_id: nil)
        review.reload

        expect(review.adjudicated_at).to be_nil,
                                         "Expected adjudicated_at to stay nil after reopen on '#{status}', but callback re-set it"
        expect(review.adjudicated_by_id).to be_nil
      end
    end
  end
end
