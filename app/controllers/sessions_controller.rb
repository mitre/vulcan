# frozen_string_literal: true

require 'net/http'
require 'json'

# Custom sessions controller to handle OIDC logout
class SessionsController < Devise::SessionsController
  include OidcDiscoveryHelper

  # The RP-initiated logout landing must work for the signed-out browser
  # the OIDC provider sends back — narrow skip, this action only.
  skip_before_action :authenticate_user!, only: :signed_out

  # AC-8: Preserve consent acknowledgment across Devise's session reset.
  # Devise calls reset_session on login (session fixation protection).
  # We save the consent timestamp before and restore it after so the
  # user doesn't have to acknowledge twice (once on login page, once after).
  #
  # We also record session[:auth_method] AFTER super so it survives the reset.
  # This lets the profile show "Signed in via email and password" vs "Signed in
  # via Okta" — distinct from user.provider (which tracks linked identities).
  def create
    consent_at = session[:consent_acknowledged_at]
    super
    session[:consent_acknowledged_at] = consent_at if consent_at.present?
    session[:auth_method] = :local if user_signed_in?
  end

  def destroy
    id_token = session[:id_token]
    # RP-initiated logout is OPTIONAL in OIDC — only attempt it when the
    # provider actually has a logout endpoint (discovered, or the
    # Okta-shaped fallback for Okta issuers). Guessing a URL for other
    # providers sent users to a 404 at the IdP instead of signing out.
    logout_endpoint = fetch_oidc_logout_endpoint if Settings.oidc.enabled && id_token.present?

    if logout_endpoint
      Rails.logger.info "OIDC logout initiated for user #{current_user&.email}"

      # Sign out the user locally
      Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)

      # Clear the ID token from session
      session.delete(:id_token)

      logout_url = build_oidc_logout_url(logout_endpoint, id_token)

      redacted_url = logout_url.gsub(/id_token_hint=[^&]+/, 'id_token_hint=[REDACTED]')
      Rails.logger.info "Redirecting to OIDC logout: #{redacted_url}"

      # Redirect to OIDC provider logout
      redirect_to logout_url, allow_other_host: true
    else
      # Non-OIDC sessions, no ID token, or a provider without a logout
      # endpoint: Devise local sign-out (flash + sign-in page via
      # after_sign_out_path_for).
      session.delete(:id_token)
      Rails.logger.info "Standard logout for user #{current_user&.email}"
      super
    end
  end

  # GET /users/signed_out — RP-initiated logout landing. The OIDC provider
  # returns the browser here after ending its session (a flash set before
  # the provider hop dies during the external redirect, so the AC-12(02)
  # logoff message must be produced on RETURN). One redirect to the
  # sign-in page — flash survives exactly one redirect. Idempotent and
  # safe for direct unauthenticated hits: it reads no session state.
  def signed_out
    redirect_to new_user_session_path, notice: t('devise.sessions.signed_out')
  end

  private

  def build_oidc_logout_url(logout_endpoint, id_token)
    # Land on the signed_out action so the user gets the AC-12(02) logoff
    # message — this URL must be registered with the provider as an
    # allowed post-logout redirect URI (see docs/deployment).
    post_logout_uri = "#{(Settings.app_url || root_url).to_s.chomp('/')}/users/signed_out"

    # Build logout URL with ID token hint and post-logout redirect
    params = {
      id_token_hint: id_token,
      post_logout_redirect_uri: post_logout_uri
    }

    # Add client_id if available (required by some providers)
    client_id = Settings.oidc.args.client_options.identifier
    params[:client_id] = client_id if client_id.present?

    "#{logout_endpoint}?#{params.to_query}"
  end

  def fetch_oidc_logout_endpoint
    # Use generalized discovery helper; nil when the provider has no
    # logout endpoint (destroy then completes the sign-out locally).
    fetch_oidc_endpoint('end_session_endpoint', okta_fallback_logout_url)
  end

  # Okta's logout endpoint follows a fixed shape, so it is a safe guess for
  # Okta issuers when discovery is unavailable (trial orgs sometimes omit
  # fields). For ANY other issuer a guessed URL is a 404 at the provider —
  # return nil instead.
  def okta_fallback_logout_url
    issuer_url = Settings.oidc.args.issuer.to_s
    host = URI.parse(issuer_url).host
    return nil unless host&.match?(/(\A|\.)okta(?:preview|-emea)?\.com\z/)

    "#{issuer_url.chomp('/')}/oauth2/v1/logout"
  rescue URI::InvalidURIError
    nil
  end
end
