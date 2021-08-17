# frozen_string_literal: true

# Rule DisaRuleDescription class
class DisaRuleDescription < ApplicationRecord
  audited associated_with: :rule, except: %i[rule_id], max_audits: 1000
  belongs_to :rule
end
