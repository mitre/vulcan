# frozen_string_literal: true

# Dual-mode auth: API token via Authorization header, falling back to Devise session.
module ApiTokenAuthenticatable
  extend ActiveSupport::Concern

  included do
    attr_reader :current_token
  end

  WRITE_METHODS = %w[POST PUT PATCH DELETE].freeze

  private

  def authenticate_user!(*)
    if api_token_request?
      authenticate_with_api_token!
    else
      super
    end
  end

  def api_token_request?
    api_tokens_enabled? && request.headers['Authorization']&.match?(/\AToken\s/i)
  end

  def api_tokens_enabled?
    Settings.api_tokens&.enabled != false
  end

  def authenticate_with_api_token!
    raw_token = extract_token_from_header
    if raw_token.blank?
      render_token_unauthorized
      return
    end

    token = PersonalAccessToken.authenticate(raw_token)
    unless token
      render_token_unauthorized
      return
    end

    unless token.ip_allowed?(request.remote_ip)
      render json: { error: 'IP address not in token allowlist' }, status: :forbidden
      return
    end

    unless scope_sufficient?(token)
      render json: { error: 'Insufficient token scope for this action' }, status: :forbidden
      return
    end

    token.touch_last_used!
    @current_token = token
    sign_in(token.user, store: false)
  end

  def extract_token_from_header
    auth = request.headers['Authorization']
    return nil unless auth

    match = auth.match(/\AToken\s+(.+)\z/i)
    match&.captures&.first
  end

  def scope_sufficient?(token)
    if WRITE_METHODS.include?(request.method)
      token.can?(:write)
    else
      token.can?(:read)
    end
  end

  def render_token_unauthorized
    render json: { error: 'Invalid or expired API token' }, status: :unauthorized
  end

  def handle_unverified_request
    if api_token_request?
      nil
    else
      super
    end
  end
end
