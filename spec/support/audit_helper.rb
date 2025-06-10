# frozen_string_literal: true

# Helper methods for managing audit context in tests
module AuditHelper
  # Execute a block with a specific user set as the auditor
  def with_audit_user(user, &block)
    if defined?(Audited)
      Audited.audit_class.as_user(user, &block)
    else
      yield
    end
  end

  # Execute a block without creating any audits
  def without_auditing
    if defined?(Audited)
      was_enabled = Audited.auditing_enabled
      Audited.auditing_enabled = false
    end
    yield
  ensure
    Audited.auditing_enabled = was_enabled if defined?(Audited) && defined?(was_enabled)
  end

  # Get or create a system user for audit purposes (without auditing to avoid circular dependency)
  def system_audit_user
    @system_audit_user ||= without_auditing do
      User.find_or_create_by!(email: 'system@vulcan.test') do |user|
        user.name = 'System User'
        user.password = SecureRandom.hex(16)
        user.confirmed_at = Time.current
        user.admin = true
      end
    end
  end
end

# Include in RSpec configuration
RSpec.configure do |config|
  config.include AuditHelper
end
