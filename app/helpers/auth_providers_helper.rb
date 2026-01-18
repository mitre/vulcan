# frozen_string_literal: true

# Helper for building authentication provider configuration for frontend
module AuthProvidersHelper
  # Build array of all enabled auth providers for login page
  # Returns array of hashes with: id, title, path
  #
  # Example output:
  # [
  #   { id: 'ldap', title: 'Corporate LDAP', path: '/users/auth/ldap' },
  #   { id: 'oidc', title: 'Okta', path: '/users/auth/oidc' },
  #   { id: 'github', title: 'Sign in with GitHub', path: '/users/auth/github' }
  # ]
  def auth_providers
    providers = []

    # LDAP provider
    if Settings.ldap.enabled
      providers << {
        id: 'ldap',
        title: Settings.ldap.servers.main.title || 'LDAP',
        path: '/users/auth/ldap',
      }
    end

    # OIDC provider (Okta, Auth0, Azure AD, etc.)
    if Settings.oidc.enabled
      providers << {
        id: 'oidc',
        title: Settings.oidc.title || 'OIDC Provider',
        path: '/users/auth/oidc',
      }
    end

    # Generic OAuth providers (GitHub, GitLab, Google, etc.)
    # Configured in vulcan.yml under 'providers:' section
    if Settings.providers.present?
      Settings.providers.each do |provider|
        # Handle both hash and OpenStruct access patterns
        provider_name = provider.try(:name) || provider[:name] || provider['name']
        provider_title = provider.try(:title) || provider[:title] || provider['title']

        providers << {
          id: provider_name.to_s,
          title: provider_title || "Sign in with #{provider_name.to_s.capitalize}",
          path: "/users/auth/#{provider_name}",
        }
      end
    end

    providers
  end
end
