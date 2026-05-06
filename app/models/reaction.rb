# frozen_string_literal: true

# A user's 👍/👎 reaction on a comment-action Review. One per (user, review).
class Reaction < ApplicationRecord
  include VulcanAuditable

  belongs_to :review
  belongs_to :user

  vulcan_audited only: %i[kind], associated_with: :review

  KINDS = %w[up down].freeze

  # rubocop:disable Rails/I18nLocaleTexts -- consistent with neighbor model validators
  validates :kind, inclusion: { in: KINDS }
  validates :user_id, uniqueness: { scope: :review_id, message: 'has already reacted to this comment' }
  # rubocop:enable Rails/I18nLocaleTexts
  validate :must_be_comment_review

  private

  def must_be_comment_review
    return unless review

    errors.add(:review, 'can only react to comment-action reviews') if review.action != 'comment'
  end
end
