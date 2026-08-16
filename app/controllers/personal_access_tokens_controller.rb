# frozen_string_literal: true

# CRUD for personal access tokens. Session-auth only (token auth rejected).
class PersonalAccessTokensController < ApplicationController
  before_action :require_api_tokens_enabled
  before_action :require_session_auth
  before_action :set_token, only: [:destroy]

  def index
    tokens = viewable_user.personal_access_tokens
                          .order(Arel.sql('revoked_at IS NOT NULL'), created_at: :desc)
    view = current_user.admin? && params[:user_id].present? ? :admin : :default
    render body: PersonalAccessTokenBlueprint.render(tokens, view: view, root: :personal_access_tokens),
           content_type: 'application/json'
  end

  def create
    unless valid_password?
      render_incorrect_password
      return
    end

    # Ownership is ALWAYS the signed-in account — a token authenticates AS
    # its owner, so minting one for someone else would make every audit
    # record attributed to them repudiable. Admin oversight of another
    # user's tokens is read (index) and revoke (admin_revoke) only; the
    # accountable admin path for account recovery is a password reset,
    # where the user re-authenticates and the admin never holds a
    # credential that speaks as them.
    token = current_user.personal_access_tokens.build(token_params)

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

    token = PersonalAccessToken.find(params.expect(:id))
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

    render_session_authentication_required
  end

  # READ-ONLY admin oversight: an admin may LIST another user's tokens
  # (name, prefix, last-used — never the secret). Deliberately not used by
  # create; see the comment there.
  def viewable_user
    if params[:user_id].present? && current_user.admin?
      User.find(params.expect(:user_id))
    else
      current_user
    end
  end

  def set_token
    @token = current_user.personal_access_tokens.find(params.expect(:id))
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
