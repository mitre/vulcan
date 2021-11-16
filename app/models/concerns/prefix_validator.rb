# frozen_string_literal: true

# Validates that a project prefix is in the correct format
class PrefixValidator < ActiveModel::Validator
  def validate(record)
    return if record.prefix.respond_to?(:match?) && validate_prefix(record.prefix)

    record.errors.add(:base, 'Prefix must be of the form AAAA-00')
  end

  private

  # Prefixes are 4 alphanumeric characters, followed by a dash, followed by 2 alphanumeric characters.
  # Ex. abcd-01
  def validate_prefix(prefix)
    return true if prefix.match?(/^\w{4}-\w{2}$/)

    false
  end
end
