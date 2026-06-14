# frozen_string_literal: true

require 'net/http'
require 'json'

# Custom sessions controller to handle OIDC logout
class SessionsController < Devise::SessionsController
  include OidcDiscoveryHelper

  # The RP-initiated logout landing must work for the signed-out browser
  # the OIDC provider sends back — narrow skip, this action only.
  skip_before_action :authenticate_user!, only: %i[signed_out complete_link]

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
    provider = session_provider_config
    logout_endpoint = fetch_oidc_logout_endpoint_for(provider) if Settings.oidc.enabled && id_token.present?

    if logout_endpoint
      Rails.logger.info "OIDC logout initiated for user #{current_user&.email}"

      Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)

      session.delete(:id_token)

      logout_url = build_oidc_logout_url(logout_endpoint, id_token, provider)

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

  def complete_link
    pending = session[:pending_link]
    unless pending
      flash.alert = 'No pending account link. Please try signing in again.'
      redirect_to new_user_session_path and return
    end

    user = User.find_by('LOWER(email) = ?', pending['email'].to_s.downcase)
    unless user
      session.delete(:pending_link)
      flash.alert = 'Account not found. Please try signing in again.'
      redirect_to new_user_session_path and return
    end

    unless user.valid_for_authentication? { user.valid_password?(params[:current_password].to_s) }
      if user.access_locked?
        session.delete(:pending_link)
        flash.alert = 'Your account has been locked due to too many failed attempts. Please try again later.'
      else
        flash.alert = 'Incorrect password. Please enter your existing account password to link.'
      end
      redirect_to new_user_session_path(link_pending: true) and return
    end

    title = OidcProviderRegistry.title_for(pending['provider'])
    user.link_identity!(
      provider: pending['provider'],
      uid: pending['uid'],
      email: pending['email'],
      audit_reason: "Linked #{title} via account verification"
    )
    session.delete(:pending_link)

    sign_in(user)
    flash.notice = "Your account has been linked to #{title} and you are now signed in."
    redirect_to root_path
  end

  private

  def build_oidc_logout_url(logout_endpoint, id_token, provider)
    post_logout_uri = "#{(Settings.app_url || root_url).to_s.chomp('/')}/users/signed_out"

    params = {
      id_token_hint: id_token,
      post_logout_redirect_uri: post_logout_uri
    }

    client_id = provider&.dig('client_id')
    params[:client_id] = client_id if client_id.present?

    "#{logout_endpoint}?#{params.to_query}"
  end

  def fetch_oidc_logout_endpoint_for(provider)
    issuer_url = provider&.dig('issuer')
    return nil unless issuer_url

    if Settings.oidc.discovery
      discovery = fetch_oidc_discovery_document(issuer_url)
      endpoint = discovery&.[]('end_session_endpoint')
      return endpoint if endpoint
    end

    okta_fallback_logout_url(issuer_url)
  end

  def okta_fallback_logout_url(issuer_url)
    host = URI.parse(issuer_url.to_s).host
    return nil unless host&.match?(/(\A|\.)okta(?:preview|-emea)?\.com\z/)

    "#{issuer_url.to_s.chomp('/')}/oauth2/v1/logout"
  rescue URI::InvalidURIError
    nil
  end

  def session_provider_config
    auth_method = session[:auth_method]&.to_s
    return nil unless auth_method

    Array(Settings.oidc&.providers).find { |p| p['name'] == auth_method } ||
      legacy_args_as_provider(auth_method)
  end

  def legacy_args_as_provider(auth_method)
    return nil unless Settings.oidc.respond_to?(:args) && Settings.oidc.args.respond_to?(:issuer)

    {
      'name' => auth_method,
      'issuer' => Settings.oidc.args.issuer,
      'client_id' => Settings.oidc.args.client_options&.identifier
    }
  end
end
