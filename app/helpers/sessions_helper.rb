# frozen_string_literal: true

# This module provides helpers for the devise/sessions views and helps
# move the logic of figuring out which login settings are enabled or
# disabled out of the view.
module SessionsHelper
  def resource_name
    User.name.underscore.to_sym
  end

  def any_form_providers_enabled?
    Settings.local_login.enabled || Devise.omniauth_providers.include?(:ldap)
  end

  def ldap_enabled?
    Devise.omniauth_providers.include?(:ldap)
  end

  def oidc_enabled?
    Settings.oidc.enabled
  end

  def oidc_title_text
    Settings.oidc.title
  end

  def local_login_enabled?
    Settings.local_login.enabled
  end

  def user_registration_enabled?
    Settings.user_registration.enabled
  end

  def non_ldap_oauth_providers
    Devise.omniauth_providers.reject { |p| p.eql?(:ldap) }
  end

  def any_oauth_providers_enabled?
    Devise.mappings[resource_name].omniauthable? && non_ldap_oauth_providers.any?
  end

  # Build auth providers configuration for Vue SPA
  # Returns array of provider hashes with id, title, path
  # ProviderButton component uses id to display Bootstrap Icons automatically
  def auth_providers_config
    providers = []

    # OIDC/OAuth providers (GitHub, Google, OIDC, etc.)
    if any_oauth_providers_enabled?
      non_ldap_oauth_providers.each do |provider|
        providers << {
          id: provider.to_s,
          title: provider == :oidc ? oidc_title_text : provider.to_s.titleize,
          path: omniauth_authorize_path(resource_name, provider)
        }
      end
    end

    # LDAP provider
    if ldap_enabled?
      ldap_server = Settings.ldap.servers.values.first
      providers << {
        id: 'ldap',
        title: ldap_server['title'] || 'LDAP',
        path: omniauth_authorize_path(resource_name, :ldap)
      }
    end

    providers
  end
end
