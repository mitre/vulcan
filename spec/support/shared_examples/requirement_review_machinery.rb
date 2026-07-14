# frozen_string_literal: true

# One review machinery for every requirement kind: locking, review
# requests, comments, and audit history must behave identically whether
# the row is a STIG Rule or a component-authored SrgRule.
#
# Consumers provide:
#   requirement — an unlocked, not-under-review requirement row (let)
#   admin_user  — a user with admin membership on the requirement's project
RSpec.shared_examples 'a requirement with shared review machinery' do
  describe 'locking' do
    it 'locks via lock_control and unlocks via unlock_control reviews' do
      Review.create!(user: admin_user, commentable: requirement,
                     action: 'lock_control', comment: 'Locking for release')
      expect(requirement.reload.locked).to be(true)

      Review.create!(user: admin_user, commentable: requirement,
                     action: 'unlock_control', comment: 'Reopening for edits')
      expect(requirement.reload.locked).to be(false)
    end

    it 'rejects locking an already-locked requirement' do
      requirement.update!(locked: true)

      review = Review.new(user: admin_user, commentable: requirement,
                          action: 'lock_control', comment: 'Locking again')
      expect(review).not_to be_valid
      expect(review.errors[:base]).to include('Control is already locked')
    end
  end

  describe 'review requests' do
    it 'request_review marks the row under review and revoke clears it' do
      Review.create!(user: admin_user, commentable: requirement,
                     action: 'request_review', comment: 'Please review')
      expect(requirement.reload.review_requestor_id).to eq(admin_user.id)

      Review.create!(user: admin_user, commentable: requirement,
                     action: 'revoke_review_request', comment: 'Withdrawn')
      expect(requirement.reload.review_requestor_id).to be_nil
    end
  end

  describe 'comments' do
    it 'defaults a top-level comment to pending triage and threads replies' do
      comment = Review.create!(user: admin_user, commentable: requirement,
                               action: 'comment', comment: 'Top-level feedback',
                               section: 'fixtext')
      expect(comment.triage_status).to eq('pending')

      reply = Review.create!(user: admin_user, commentable: requirement,
                             action: 'comment', comment: 'A reply',
                             responding_to_review_id: comment.id, section: 'fixtext')
      expect(reply.triage_status).to be_nil
      expect(comment.responses).to contain_exactly(reply)
    end
  end

  describe 'audit history' do
    include_context 'with auditing'

    it 'audits content updates, associated with the component' do
      expect { requirement.update!(title: 'Audited title change') }
        .to change { requirement.audits.count }.by(1)

      expect(requirement.audits.last.associated).to eq(requirement.component)
    end
  end
end
