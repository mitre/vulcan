# frozen_string_literal: true

# CRUD for personal access tokens. Session-auth only (token auth rejected).
class PersonalAccessTokensController < ApplicationController
  before_action :require_api_tokens_enabled
  before_action :require_session_auth
  before_action :set_token, only: [:destroy]

  def index
    tokens = target_user.personal_access_tokens
                        .order(Arel.sql('revoked_at IS NOT NULL'), created_at: :desc)
    view = current_user.admin? && params[:user_id].present? ? :admin : :default
    render body: PersonalAccessTokenBlueprint.render(tokens, view: view, root: :personal_access_tokens),
           content_type: 'application/json'
  end

  def create
    unless valid_password?
      render json: { error: 'Current password is incorrect' }, status: :unauthorized
      return
    end

    token = target_user.personal_access_tokens.build(token_params)

    if token.save
      render json: {
        token: token.raw_token,
        personal_access_token: PersonalAccessTokenBlueprint.render_as_json(token)
      }, status: :created
    else
      render_toast(title: 'Could not create token.', message: token.errors.full_messages,
                   status: :unprocessable_content)
    end
  end

  def destroy
    @token.revoke!
    render_toast(title: 'Token revoked.', message: ["'#{@token.name}' has been revoked."],
                 variant: 'success', status: :ok)
  end

  def admin_revoke
    raise NotAuthorizedError, 'Admin access required.' unless current_user.admin?

    token = PersonalAccessToken.find(params[:id])
    token.audit_comment = params[:audit_comment] if token.respond_to?(:audit_comment=)
    token.revoke!
    render_toast(title: 'Token revoked.', message: ["Admin revoked '#{token.name}' for #{token.user.name}."],
                 variant: 'success', status: :ok)
  end

  private

  def require_api_tokens_enabled
    return if Settings.api_tokens&.enabled != false

    render_not_found
  end

  def require_session_auth
    return unless @current_token

    render json: { error: 'Token management requires session authentication' }, status: :forbidden
  end

  def target_user
    if params[:user_id].present? && current_user.admin?
      User.find(params[:user_id])
    else
      current_user
    end
  end

  def set_token
    @token = current_user.personal_access_tokens.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def valid_password?
    password = params.dig(:personal_access_token, :current_password)
    return false if password.blank?

    current_user.valid_password?(password)
  end

  def token_params
    params.expect(personal_access_token: [:name, :expires_at, { scopes: [], allowed_ips: [] }])
  end
end
