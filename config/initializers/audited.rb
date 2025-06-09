# frozen_string_literal: true

# Audited initializer
Rails.application.reloader.to_prepare do
  Audited.config do |config|
    config.audit_class = VulcanAudit
    config.current_user_method = :current_user
  end

  # Force removal of presence validations using our custom method
  # This handles cases where Rails re-adds validations after class loading
  VulcanAudit.remove_presence_validations!
end

# Configure Warden to set audit user on authentication
# This ensures audits are properly associated with the authenticated user
if defined?(Warden)
  Warden::Manager.after_set_user do |user, _auth, opts|
    # Only set for non-fetch operations (actual login)
    Audited.store[:current_user] = user if opts[:event] != :fetch && user
  end

  Warden::Manager.before_logout do |_user, _auth, _opts|
    Audited.store[:current_user] = nil
  end
end
