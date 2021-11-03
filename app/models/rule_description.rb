# frozen_string_literal: true

# Rule RuleDescription class
class RuleDescription < ApplicationRecord
  audited associated_with: :base_rule, except: %i[base_rule_id], max_audits: 1000
  belongs_to :base_rule
end
