# frozen_string_literal: true

require 'net/http'
require 'json'

# Custom sessions controller to handle OIDC logout
class SessionsController < Devise::SessionsController
  def destroy
    id_token = session[:id_token]

    # If using OIDC and we have an ID token, handle OIDC logout
    if Settings.oidc.enabled && id_token.present?
      Rails.logger.info "OIDC logout initiated for user #{current_user&.email}"

      # Sign out the user locally
      Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)

      # Clear the ID token from session
      session.delete(:id_token)

      # Build OIDC logout URL using Settings
      logout_url = build_oidc_logout_url(id_token)

      redacted_url = logout_url.gsub(/id_token_hint=[^&]+/, 'id_token_hint=[REDACTED]')
      Rails.logger.info "Redirecting to OIDC logout: #{redacted_url}"

      # Redirect to OIDC provider logout
      redirect_to logout_url, allow_other_host: true
    else
      # For non-OIDC or when no ID token, use default Devise behavior
      Rails.logger.info "Standard logout for user #{current_user&.email}"
      super
    end
  end

  private

  def build_oidc_logout_url(id_token)
    # Get the end_session_endpoint from OIDC discovery
    logout_endpoint = fetch_oidc_logout_endpoint

    # Use app URL from Settings
    post_logout_uri = Settings.app_url || root_url

    # Build logout URL with ID token hint and post-logout redirect
    params = {
      id_token_hint: id_token,
      post_logout_redirect_uri: post_logout_uri
    }

    # Add client_id if available (required by some providers)
    client_id = Settings.oidc.args.client_options.identifier || ENV.fetch('VULCAN_OIDC_CLIENT_ID', nil)
    params[:client_id] = client_id if client_id.present?

    "#{logout_endpoint}?#{params.to_query}"
  end

  def fetch_oidc_logout_endpoint
    # Try to get from session cache first
    if session[:oidc_logout_endpoint].present?
      Rails.logger.debug { "Using cached OIDC logout endpoint: #{session[:oidc_logout_endpoint]}" }
      return session[:oidc_logout_endpoint]
    end

    issuer_url = Settings.oidc.args.issuer || ENV.fetch('VULCAN_OIDC_ISSUER_URL', nil)
    discovery_url = "#{issuer_url.to_s.chomp('/')}/.well-known/openid-configuration"

    Rails.logger.info "Fetching OIDC discovery document from: #{discovery_url}"

    begin
      # Fetch the discovery document
      response = Net::HTTP.get_response(URI(discovery_url))

      if response.is_a?(Net::HTTPSuccess)
        discovery = JSON.parse(response.body)
        logout_endpoint = discovery['end_session_endpoint']

        if logout_endpoint.present?
          Rails.logger.info "Found OIDC logout endpoint: #{logout_endpoint}"
          # Cache in session to avoid repeated fetches
          session[:oidc_logout_endpoint] = logout_endpoint
          logout_endpoint
        else
          Rails.logger.warn 'No end_session_endpoint in discovery document, using OKTA fallback'
          "#{issuer_url.to_s.chomp('/')}/oauth2/v1/logout"
        end
      else
        # Fall back to OKTA endpoint if discovery fails
        Rails.logger.warn "Failed to fetch OIDC discovery document: HTTP #{response.code} - #{response.message}"
        "#{issuer_url.to_s.chomp('/')}/oauth2/v1/logout"
      end
    rescue StandardError => e
      # Fall back to OKTA endpoint on any error
      Rails.logger.error "Error fetching OIDC discovery: #{e.class} - #{e.message}"
      Rails.logger.debug { e.backtrace.join("\n") } if Rails.env.development?
      "#{issuer_url.to_s.chomp('/')}/oauth2/v1/logout"
    end
  end
end
