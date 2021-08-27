# frozen_string_literal: true

# Raised when a Rule cannot be successfully rolled back to a previous state
class RuleRevertError < StandardError
  def initialize(message = 'Could not revert history for rule.')
    super message
  end
end
