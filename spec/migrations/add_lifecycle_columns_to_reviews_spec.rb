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

    # PR-717 review remediation .1 — the original migration set
    # `triage_status NOT NULL DEFAULT 'pending'`, but a follow-up migration
    # (20260502120000_make_review_triage_status_nullable) drops the
    # default + allows NULL. Schema-level inspection now expects nil for
    # an unsaved Review.new; new top-level comments get 'pending' from
    # the model's before_create callback (see app/models/review.rb).
    expect(review.triage_status).to be_nil
  end

  it 'has the expected indexes' do
    indexes = ActiveRecord::Base.connection.indexes(:reviews).map(&:columns)
    expect(indexes).to include(%w[action triage_status])
    expect(indexes).to include(%w[rule_id section triage_status])
    expect(indexes).to include(['responding_to_review_id'])
    expect(indexes).to include(['duplicate_of_review_id'])
  end
end
