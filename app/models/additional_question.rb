# frozen_string_literal: true

# These are additional questions on a component which users must fill out
# for rules on that component
class AdditionalQuestion < ApplicationRecord
  amoeba do
    include_association :additional_answers
  end

  audited except: %i[component_id created_at updated_at], associated_with: :component, max_audits: 1000

  FIELD_TYPES = %w[dropdown freeform].freeze

  enum question_type: FIELD_TYPES.zip(FIELD_TYPES).to_h

  validates :name, :question_type, presence: true

  validates :options, presence: true, if: -> { question_type.eql?(:dropdown) }

  validates :name, uniqueness: { scope: :component_id }

  belongs_to :component

  has_many :additional_answers, dependent: :destroy
end
