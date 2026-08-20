# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review, '.bulk_triage' do
  include_context 'srg model base setup'

  let!(:first_comment) { create(:review, :comment, comment: 'first', section: nil, user: p_viewer, rule: rule) }
  let!(:second_comment) { create(:review, :comment, comment: 'second', section: nil, user: p_viewer, rule: rule) }

  describe 'argument validation' do
    it 'raises ArgumentError on empty array' do
      expect do
        Review.bulk_triage(reviews: [], triage_status: 'concur', user: p_admin)
      end.to raise_error(ArgumentError, 'No comments selected.')
    end

    it 'raises ArgumentError when reviews span multiple components' do
      other_component = Component.create!(
        project: project, name: 'Other', title: 'Other STIG',
        version: 'Other V1R1', prefix: 'OTHR-01', based_on: srg
      )
      other_rule = other_component.rules.first
      other_comment = create(:review, :comment, comment: 'x', section: nil, user: p_viewer, rule: other_rule)

      expect do
        Review.bulk_triage(reviews: [first_comment, other_comment], triage_status: 'concur', user: p_admin)
      end.to raise_error(ArgumentError, 'Bulk triage cannot span multiple components.')
    end
  end

  describe 'successful triage' do
    it 'sets triage_status, triage_set_by_id, and audit_comment on all reviews' do
      result = Review.bulk_triage(reviews: [first_comment, second_comment], triage_status: 'concur', user: p_admin)

      first_comment.reload
      second_comment.reload
      expect(first_comment.triage_status).to eq('concur')
      expect(first_comment.triage_set_by_id).to eq(p_admin.id)
      expect(second_comment.triage_status).to eq('concur')
      expect(second_comment.triage_set_by_id).to eq(p_admin.id)
      expect(result[:reviews]).to contain_exactly(first_comment, second_comment)
    end

    it 'creates response reviews when response_comment is provided' do
      result = Review.bulk_triage(
        reviews: [first_comment, second_comment], triage_status: 'concur',
        user: p_admin, response_comment: 'Acknowledged, will implement.'
      )

      expect(result[:response_reviews].size).to eq(2)
      result[:response_reviews].each do |response|
        expect(response.comment).to eq('Acknowledged, will implement.')
        expect(response.user).to eq(p_admin)
        expect(response.action).to eq('comment')
        expect(response.responding_to_review_id).to be_present
      end
    end

    it 'skips response creation when response_comment is blank' do
      result = Review.bulk_triage(
        reviews: [first_comment, second_comment], triage_status: 'concur',
        user: p_admin, response_comment: ''
      )

      expect(result[:response_reviews]).to be_empty
    end
  end

  describe 'transaction safety' do
    it 'rolls back all changes when one review update fails mid-loop' do
      allow(second_comment).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(second_comment))

      expect do
        Review.bulk_triage(reviews: [first_comment, second_comment], triage_status: 'concur', user: p_admin)
      end.to raise_error(ActiveRecord::RecordInvalid)

      first_comment.reload
      expect(first_comment.triage_status).to eq('pending')
    end
  end
end
