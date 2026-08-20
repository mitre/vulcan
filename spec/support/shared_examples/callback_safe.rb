# frozen_string_literal: true

# Parametric shared examples for callback safety.
# Generates tests for ALL enum values of a field, preventing the class of
# bug where only one value is tested and a callback conflict on a different
# value goes undetected (e.g., reopen only tested with 'concur', missed the
# callback fight on terminal statuses).
#
# Usage:
#   include_examples 'clears stale FKs for all triage statuses'
#   include_examples 'auto-adjudicates only terminal statuses'
#
# Requires these `let` values in the including context:
#   let(:callback_user) { ... }  — user who owns the review
#   let(:callback_rule) { ... }  — rule the review is on
#   let(:callback_triager) { ... } — user setting the triage status

RSpec.shared_examples 'clears stale FKs for all triage statuses' do
  Review::TRIAGE_STATUSES.each do |status|
    context "when triage_status is '#{status}'" do
      it "clears duplicate_of_review_id unless status is 'duplicate'" do
        review = create(:review, :comment, comment: 'fk test', section: nil,
                                           user: callback_user, rule: callback_rule)
        other = create(:review, :comment, comment: 'other', section: nil,
                                          user: callback_user, rule: callback_rule)

        attrs = { triage_status: status, triage_set_by_id: callback_triager.id,
                  triage_set_at: Time.current, duplicate_of_review_id: other.id }
        attrs[:addressed_by_rule_id] = callback_rule.id if status == 'addressed_by'

        review.assign_attributes(attrs)
        review.valid?

        if status == 'duplicate'
          expect(review.duplicate_of_review_id).to eq(other.id)
        else
          expect(review.duplicate_of_review_id).to be_nil
        end
      end

      it "clears addressed_by_rule_id unless status is 'addressed_by'" do
        review = create(:review, :comment, comment: 'ab test', section: nil,
                                           user: callback_user, rule: callback_rule)

        attrs = { triage_status: status, triage_set_by_id: callback_triager.id,
                  triage_set_at: Time.current, addressed_by_rule_id: callback_rule.id }

        review.assign_attributes(attrs)
        review.valid?

        if status == 'addressed_by'
          expect(review.addressed_by_rule_id).to eq(callback_rule.id)
        else
          expect(review.addressed_by_rule_id).to be_nil
        end
      end
    end
  end
end

RSpec.shared_examples 'auto-adjudicates only terminal statuses' do
  Review::TRIAGE_STATUSES.each do |status|
    expected = Review::TERMINAL_AUTO_ADJUDICATE_STATUSES.include?(status) ? 'sets' : 'does not set'

    it "#{expected} adjudicated_at for '#{status}'" do
      review = create(:review, :comment, comment: 'adj test', section: nil,
                                         user: callback_user, rule: callback_rule)

      attrs = { triage_status: status, triage_set_by_id: callback_triager.id, triage_set_at: Time.current }
      if status == 'duplicate'
        dup_target = create(:review, :comment, comment: 'dup target', section: nil,
                                               user: callback_user, rule: callback_rule)
        attrs[:duplicate_of_review_id] = dup_target.id
      end
      attrs[:addressed_by_rule_id] = callback_rule.id if status == 'addressed_by'

      review.update!(attrs)
      review.reload

      if Review::TERMINAL_AUTO_ADJUDICATE_STATUSES.include?(status)
        expect(review.adjudicated_at).to be_present,
                                         "Expected adjudicated_at set for terminal status '#{status}'"
      else
        expect(review.adjudicated_at).to be_nil,
                                         "Expected adjudicated_at nil for non-terminal status '#{status}'"
      end
    end
  end
end
