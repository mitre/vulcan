# frozen_string_literal: true

# Raised when a Rule cannot be successfully rolled back to a previous state
class RuleRevertError < StandardError
  def initialize(id, field)
    super "Cannot rollback the #{field} field for Control #{id}"
  end
end
