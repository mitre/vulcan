# frozen_string_literal: true

# Rule RuleDescription class
class RuleDescription < ApplicationRecord
  audited associated_with: :rule, except: %i[rule_id], max_audits: 1000
  belongs_to :rule
end
