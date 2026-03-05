# frozen_string_literal: true

# Rule RuleDescription class
class RuleDescription < ApplicationRecord
  include VulcanAuditable

  vulcan_audited associated_with: :base_rule, except: %i[base_rule_id]
  belongs_to :base_rule
end
