# frozen_string_literal: true

# These are additional answers for the additional questions on a specific component
class AdditionalAnswer < ApplicationRecord
  audited only: %i[answer], associated_with: :rule, max_audits: 1000

  validates :additional_question_id, uniqueness: { scope: :rule_id }

  belongs_to :additional_question
  belongs_to :rule

  URL_REGEXP = %r{\A(http|https)://[a-z0-9@:%._+~#=]{2,256}\.[a-z]{2,16}\b([-a-z0-9@:%_+.~#?&/=]*)\z}ix
  validates :answer, format: { with: URL_REGEXP },
                     if: :present_and_type_is_url?

  def present_and_type_is_url?
    additional_question.question_type == 'url' && !answer.empty?
  end
end
