# frozen_string_literal: true

# Validates password complexity against configurable rules from Settings.password.
# Only runs when Devise's password_required? returns true AND the user is local
# (skips OmniAuth users who use random token passwords).
#
# Configuration via environment variables (DoD-aligned defaults: 15 chars, 2 of each):
#   VULCAN_PASSWORD_MIN_LENGTH      - Minimum total length (default: 15)
#   VULCAN_PASSWORD_MIN_UPPERCASE   - Minimum uppercase letters (default: 2, 0 = disabled)
#   VULCAN_PASSWORD_MIN_LOWERCASE   - Minimum lowercase letters (default: 2, 0 = disabled)
#   VULCAN_PASSWORD_MIN_NUMBER      - Minimum digits (default: 2, 0 = disabled)
#   VULCAN_PASSWORD_MIN_SPECIAL     - Minimum special characters (default: 2, 0 = disabled)
module PasswordComplexityValidator
  extend ActiveSupport::Concern

  included do
    validate :validate_password_complexity, if: :password_complexity_required?
  end

  # Skip complexity for OmniAuth users (they use random tokens, not user-chosen passwords)
  def password_complexity_required?
    password_required? && provider.blank?
  end

  private

  def validate_password_complexity
    return if password.blank?

    policy = Settings.password

    validate_min_length(policy)
    validate_char_count(policy, :min_uppercase, /[A-Z]/, 'uppercase letter')
    validate_char_count(policy, :min_lowercase, /[a-z]/, 'lowercase letter')
    validate_char_count(policy, :min_number, /\d/, 'number')
    validate_char_count(policy, :min_special, /[^A-Za-z0-9]/, 'special character')
  end

  def validate_min_length(policy)
    min = policy.min_length.to_i
    return unless password.length < min

    errors.add(:password, "must be at least #{min} characters long")
  end

  def validate_char_count(policy, setting, pattern, label)
    required = policy.send(setting).to_i
    return unless required.positive?

    actual = password.scan(pattern).size
    return unless actual < required

    noun = required == 1 ? label : "#{label}s"
    errors.add(:password, "must include at least #{required} #{noun}")
  end
end
