# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AddLifecycleColumnsToReviews migration' do
  it 'adds the expected columns with correct defaults' do
    review = Review.new(action: 'comment', comment: 'x', user_id: 1, rule_id: 1)
    expect(review).to respond_to(:triage_status)
    expect(review).to respond_to(:triage_set_by_id)
    expect(review).to respond_to(:triage_set_at)
    expect(review).to respond_to(:adjudicated_at)
    expect(review).to respond_to(:adjudicated_by_id)
    expect(review).to respond_to(:duplicate_of_review_id)
    expect(review).to respond_to(:responding_to_review_id)
    expect(review).to respond_to(:section)

    expect(review.triage_status).to eq('pending')
  end

  it 'has the expected indexes' do
    indexes = ActiveRecord::Base.connection.indexes(:reviews).map(&:columns)
    expect(indexes).to include(%w[action triage_status])
    expect(indexes).to include(%w[rule_id section triage_status])
    expect(indexes).to include(['responding_to_review_id'])
    expect(indexes).to include(['duplicate_of_review_id'])
  end
end
