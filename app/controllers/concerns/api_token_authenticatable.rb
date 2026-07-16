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
      render_invalid_token
      return
    end

    token = PersonalAccessToken.authenticate(raw_token)
    unless token
      render_invalid_token
      return
    end

    unless token.ip_allowed?(request.remote_ip)
      render_ip_not_allowed
      return
    end

    unless scope_sufficient?(token)
      render_insufficient_token_scope(required_scope)
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
    token.can?(required_scope)
  end

  def required_scope
    WRITE_METHODS.include?(request.method) ? 'write' : 'read'
  end

  def handle_unverified_request
    if api_token_request?
      nil
    else
      super
    end
  end
end
