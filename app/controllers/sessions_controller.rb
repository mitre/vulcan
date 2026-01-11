# frozen_string_literal: true

require 'net/http'
require 'json'

# Custom sessions controller to handle OIDC logout
class SessionsController < Devise::SessionsController
  include OidcDiscoveryHelper

  layout 'devise'

  # Fix for GitHub Issue #700: Prevent infinite redirect loop
  # Skip authentication requirements that would create redirect loop
  skip_before_action :setup_navigation
  skip_before_action :authenticate_user!
  skip_before_action :check_access_request_notifications

  # Custom new action to clear stored location and prevent redirect loop
  def new
    # Clear stored location to avoid post-login redirect issues
    store_location_for(:user, nil)
    super
  end

  def create
    # Handle JSON requests for Vue SPA
    respond_to do |format|
      format.json do
        self.resource = warden.authenticate!(auth_options)
        sign_in(resource_name, resource)
        render json: { user: resource.as_json(only: %i[id email admin]) }, status: :ok
      end
      format.html { super }
    end
  end

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
    # Use generalized discovery helper
    fetch_oidc_endpoint('end_session_endpoint', okta_fallback_logout_url)
  end

  def okta_fallback_logout_url
    issuer_url = Settings.oidc.args.issuer || ENV.fetch('VULCAN_OIDC_ISSUER_URL', nil)
    "#{issuer_url.to_s.chomp('/')}/oauth2/v1/logout"
  end
end
