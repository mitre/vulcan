# frozen_string_literal: true

# These are additional answers for the additional questions on a specific component
class AdditionalAnswer < ApplicationRecord
  audited only: %i[answer], associated_with: :rule, max_audits: 1000

  belongs_to :additional_question
  belongs_to :rule
end
