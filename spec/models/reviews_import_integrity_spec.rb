# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review do
  describe 'valid?(:import_integrity) context' do
    include_context 'srg model base setup'

    let_it_be(:outsider) { create(:user) }

    describe 'permission validators are skipped' do
      it 'passes for a user with no project membership' do
        review = build(:review, :comment, comment: 'imported', section: nil,
                                          user: outsider, rule: rule)
        review.save!(validate: false)
        expect(review.valid?(:import_integrity)).to be(true)
      end

      it 'fails under :create context for the same record (permission validators fire)' do
        review = build(:review, :comment, comment: 'imported', section: nil,
                                          user: outsider, rule: rule)
        expect(review.valid?(:create)).to be(false)
        expect(review.errors[:base].join).to include('no permissions')
      end
    end

    describe 'structural validators still fire' do
      it 'rejects invalid triage_status' do
        review = build(:review, :comment, comment: 'x', section: nil, user: p_admin, rule: rule)
        review.save!(validate: false)
        review.triage_status = 'totally_bogus'
        expect(review.valid?(:import_integrity)).to be(false)
        expect(review.errors[:triage_status]).to be_present
      end

      it 'rejects invalid section' do
        review = build(:review, :comment, comment: 'x', section: 'not_a_section', user: p_admin, rule: rule)
        review.save!(validate: false)
        expect(review.valid?(:import_integrity)).to be(false)
        expect(review.errors[:section]).to be_present
      end

      it 'rejects cross-rule reply (responding_to on different rule)' do
        other_rule = component.rules.second
        parent = create(:review, :comment, comment: 'parent', section: nil, user: p_admin, rule: other_rule)
        review = build(:review, :comment, comment: 'x', section: nil, user: p_admin, rule: rule,
                                          responding_to_review_id: parent.id)
        review.save!(validate: false)
        expect(review.valid?(:import_integrity)).to be(false)
        expect(review.errors.full_messages.join).to match(/same rule/i)
      end

      it 'rejects chained duplicate (duplicate_of points to another duplicate)' do
        survivor = create(:review, :comment, comment: 'survivor', section: nil, user: p_admin, rule: rule)
        target = create(:review, :comment, comment: 'dup target', section: nil, user: p_admin, rule: rule)
        target.update!(triage_status: 'duplicate', duplicate_of_review_id: survivor.id,
                       triage_set_by_id: p_admin.id, triage_set_at: Time.current)

        review = build(:review, :comment, comment: 'x', section: nil, user: p_admin, rule: rule,
                                          triage_status: 'duplicate', duplicate_of_review_id: target.id,
                                          triage_set_by_id: p_admin.id, triage_set_at: Time.current)
        review.save!(validate: false)
        expect(review.valid?(:import_integrity)).to be(false)
        expect(review.errors.full_messages.join).to match(/another duplicate/i)
      end
    end
  end
end
