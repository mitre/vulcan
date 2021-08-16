# frozen_string_literal: true

# Rule RuleDescription class
class RuleDescription < ApplicationRecord
  audited associated_with: :rule
  belongs_to :rule
end
