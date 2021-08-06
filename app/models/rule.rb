# frozen_string_literal: true

class Rule < ApplicationRecord
  before_validation :error_if_locked, on: :update

  # Allow an authorized user to unlock a rule
  def self.unlock(rule, user)
    raise(RuleLockedError, "Control #{rule.id} is locked and cannot be changed.") unless user.can_unlock?(rule)
    rule.locked = false
    rule.save(validate: false)
  end

  private

  def error_if_locked
    # locked = current update
    # locked_was = before
    # If the previous state was not locked, updates can be made.
    return unless locked_was

    # If the previous state was locked, error
    raise(RuleLockedError, "Control #{id} is locked and cannot be changed.") if locked_was
  end
end
