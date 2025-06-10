# frozen_string_literal: true

# Override Devise test helpers to properly set audit context
module DeviseAuditHelper
  def sign_in(resource, deprecated = nil, scope: nil)
    result = super
    # Set the audit user after sign in - this overrides any existing audit user
    Audited.store[:current_user] = resource if resource
    result
  end

  def sign_out(resource_or_scope)
    result = super
    # Clear the audit user after sign out
    Audited.store[:current_user] = nil
    result
  end
end

# Prepend to controller specs to override Devise helpers
RSpec.configure do |config|
  # Use prepend instead of include to ensure our methods are called first
  config.before(:each, type: :controller) do
    singleton_class.prepend DeviseAuditHelper
  end
end
