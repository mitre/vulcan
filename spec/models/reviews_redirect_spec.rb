# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review do
  include_context 'srg model base setup'

  describe 'redirect_to_parent_if_satisfied_by (before_create)' do
    let_it_be(:parent_rule) { component.rules.second }

    context 'when rule has a satisfied_by parent' do
      before do
        RuleSatisfaction.create!(rule_id: rule.id, satisfied_by_rule_id: parent_rule.id)
      end

      it 'redirects comment to parent rule' do
        review = Review.create!(action: 'comment', comment: 'child concern',
                                section: nil, user: p_admin, rule: rule)
        expect(review.rule_id).to eq(parent_rule.id)
        expect(review.commentable_id).to eq(parent_rule.id)
      end

      it 'sets original_commentable_id to the child rule' do
        review = Review.create!(action: 'comment', comment: 'child concern',
                                section: nil, user: p_admin, rule: rule)
        expect(review.original_commentable_id).to eq(rule.id)
      end

      it 'prepends [Re: PREFIX-RULE_ID] to the comment' do
        review = Review.create!(action: 'comment', comment: 'vendor issue',
                                section: nil, user: p_admin, rule: rule)
        expect(review.comment).to start_with("[Re: #{component.prefix}-#{rule.rule_id}]")
        expect(review.comment).to include('vendor issue')
      end

      it 'does NOT redirect non-comment actions' do
        review = Review.create!(action: 'request_review', comment: 'review pls',
                                section: nil, user: p_admin, rule: rule)
        expect(review.rule_id).to eq(rule.id)
        expect(review.original_commentable_id).to be_nil
      end
    end

    context 'when rule has no satisfied_by parent' do
      it 'does not redirect — rule stays unchanged' do
        review = Review.create!(action: 'comment', comment: 'standalone',
                                section: nil, user: p_admin, rule: rule)
        expect(review.rule_id).to eq(rule.id)
        expect(review.original_commentable_id).to be_nil
      end
    end
  end
end
