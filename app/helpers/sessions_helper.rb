# frozen_string_literal: true

# This module provides helpers for the devise/sessions views and helps
# move the logic of figuring out which login settings are enabled or
# disabled out of the view.
module SessionsHelper
  def any_form_providers_enabled?
    Settings.local_login.enabled || Devise.omniauth_providers.include?(:ldap)
  end

  def ldap_enabled?
    Devise.omniauth_providers.include?(:ldap)
  end

  def local_login_enabled?
    Settings.local_login.enabled
  end

  def non_ldap_oauth_providers
    resource_class.omniauth_providers.reject { |p| p.eql?(:ldap) }
  end

  def any_oauth_providers_enabled?
    devise_mapping.omniauthable? && non_ldap_oauth_providers.count.positive?
  end
end
