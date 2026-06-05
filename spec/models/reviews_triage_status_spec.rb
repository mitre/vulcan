# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review do
  include_context 'reviews model base setup'

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

  describe 'parametric callback safety — all triage statuses' do
    let(:callback_user) { @p_viewer }
    let(:callback_rule) { @p1r1 }
    let(:callback_triager) { @p_admin }

    it_behaves_like 'clears stale FKs for all triage statuses'
    it_behaves_like 'auto-adjudicates only terminal statuses'

    it 'auto-adjudicates normally when save_intent is nil (default)' do
      review = create(:review, :comment, comment: 'nil intent', section: nil, user: @p_viewer, rule: @p1r1)
      expect(review.save_intent).to be_nil

      review.update!(triage_status: 'informational', triage_set_by_id: @p_admin.id, triage_set_at: Time.current)
      review.reload
      expect(review.adjudicated_at).to be_present
    end
  end

  describe 'auto_set_adjudicated skips when adjudicated_at already present' do
    it 'does not overwrite explicit adjudicated_by_id with callback default' do
      review = create(:review, :comment, comment: 'x', section: nil, user: @p_viewer, rule: @p1r1)
      explicit_admin = @p_admin

      review.update!(
        triage_status: 'withdrawn',
        adjudicated_at: Time.current,
        adjudicated_by_id: explicit_admin.id,
        triage_set_by_id: @p_author.id,
        triage_set_at: Time.current
      )

      review.reload
      expect(review.adjudicated_by_id).to eq(explicit_admin.id)
    end
  end
end
