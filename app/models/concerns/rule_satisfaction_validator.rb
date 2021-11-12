# frozen_string_literal: true

# Validates that a rule cannot satisfy itself and can only either satisfy other rules or be satisfied by other rules
class RuleSatisfactionValidator < ActiveModel::Validator
  def validate(record)
    record.errors.add(:base, 'Rule cannot satisfy itself') if record.satisfies.include?(record)

    return if record.satisfies.empty? || record.satisfied_by.empty?

    record.errors.add(:base, 'Rule can only either satisfy other rules or be satisfied by other rules, not both')
  end
end
