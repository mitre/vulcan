# frozen_string_literal: true

class RuleLockedError < StandardError
  def initialize(id)
    super "Control #{id} is locked and cannot be changed."
  end
end
