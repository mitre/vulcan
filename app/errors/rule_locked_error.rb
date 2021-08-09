# frozen_string_literal: true

# Raised when a Rule has locked: true attribute
class RuleLockedError < StandardError
  def initialize(id)
    super "Control #{id} is locked and cannot be changed."
  end
end
