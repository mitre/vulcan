# frozen_string_literal: true

# Rules, also known as Controls, are the smallest unit of enforceable configuration found in a
# Benchmark XCCDF.
class Rule < ApplicationRecord
  before_validation :error_if_locked, on: :update
  before_destroy :error_if_locked

  # Allow an authorized user to unlock a rule
  def self.unlock(user, rule)
    raise(RuleLockedError, rule.id) unless user.can_manage_rule_lock?(rule)

    # update_attribute bypasses validations on purpose to unlock the rule
    # rubocop:disable Rails/SkipsModelValidations
    rule.update_attribute(:locked, false)
    # rubocop:enable Rails/SkipsModelValidations
  end

  private

  def error_if_locked
    # locked = current update
    # locked_was = before
    # If the previous state was not locked, updates can be made.
    return unless locked_was

    # If the previous state was locked, error
    raise(RuleLockedError, id) if locked_was
  end
end
