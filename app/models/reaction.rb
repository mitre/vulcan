# frozen_string_literal: true

# A user's 👍/👎 reaction on a comment-action Review. One per (user, review).
class Reaction < ApplicationRecord
  include VulcanAuditable

  belongs_to :review
  belongs_to :user

  vulcan_audited only: %i[kind], associated_with: :review

  KINDS = %w[up down].freeze
  KIND_LABELS = { 'up' => 'Thumbs up', 'down' => 'Thumbs down' }.freeze
  CSV_LABELS  = { 'up' => 'thumbs-up', 'down' => 'thumbs-down' }.freeze

  def self.summary(review_ids, current_user_id = nil)
    return {} if review_ids.blank?

    counts = where(review_id: review_ids).group(:review_id, :kind).count
    mine = if current_user_id
             where(review_id: review_ids, user_id: current_user_id)
               .pluck(:review_id, :kind).to_h
           else
             {}
           end

    review_ids.index_with do |rid|
      {
        up: counts[[rid, 'up']] || 0,
        down: counts[[rid, 'down']] || 0,
        mine: mine[rid]
      }
    end
  end

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
