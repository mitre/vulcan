# frozen_string_literal: true

# Rule DisaRuleDescription class
class DisaRuleDescription < ApplicationRecord
  audited associated_with: :rule
  belongs_to :rule
end
