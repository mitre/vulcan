# frozen_string_literal: true

# Rules, also known as Controls, are the smallest unit of enforceable configuration found in a
# Benchmark XCCDF.
class Rule < ApplicationRecord
  audited except: %i[created_at updated_at locked], max_audits: 1000
  before_validation :error_if_locked, on: :update
  before_destroy :error_if_locked

  has_many :comments, dependent: :destroy
  belongs_to :project

  # Allow an authorized user to unlock a rule
  def self.unlock(user)
    # Can a user manage the project this rule is part of?
    raise(RuleLockedError, rule.id) unless user.can_admin_project?(project)

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
