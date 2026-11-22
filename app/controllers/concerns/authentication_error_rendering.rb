# frozen_string_literal: true

# Problem documents for authentication failures: who the caller is, whether
# their credentials or session are usable, and what a token may do. Bodies go
# through ErrorRendering#render_problem, so the envelope (type URI, title,
# status, detail, media type) is the same as every other problem; this concern
# owns only the authentication vocabulary. ApplicationController includes both
# concerns.
module AuthenticationErrorRendering
  extend ActiveSupport::Concern

  # Both authentication methods, spelled out for 401 bodies — a failed
  # request must say how to authenticate, not just that it did not.
  HOW_TO_AUTHENTICATE = {
    session: 'Sign in through the web UI (/users/sign_in) and retry with the session cookie.',
    token: 'Create a personal access token (your profile page, or POST /personal_access_tokens) ' \
           'and send it in the request header: Authorization: Token <your-token>.'
  }.freeze

  # The no-credentials / no-valid-session explanation. A cleared session
  # cookie is indistinguishable from never-signed-in at the controller
  # branch, so the detail covers every way a session ends. Shared with the
  # Devise failure app (SessionAwareFailureApp) so the copy never drifts.
  NOT_AUTHENTICATED_DETAIL =
    'This request included no API token and no valid signed-in session. If you were signed in, ' \
    'the session may have timed out, been signed out, or ended because this account signed in ' \
    'from another location.'

  # What a person sees when their form's authenticity token no longer
  # matches the session (signed out in another tab, session reset): the HTML
  # flash and the toast both use it. API clients read the problem's detail,
  # which carries the steps to recover.
  FORM_SESSION_EXPIRED_MESSAGE = 'Your form session expired. Reload the page and try again.'

  private

  # 401: no API token and no valid session.
  def render_not_authenticated
    render_problem(
      type: :not_authenticated, title: 'Not authenticated', status: :unauthorized,
      detail: NOT_AUTHENTICATED_DETAIL,
      how_to_authenticate: HOW_TO_AUTHENTICATE
    )
  end

  def render_invalid_token
    render_problem(
      type: :invalid_token, title: 'Invalid or expired API token', status: :unauthorized,
      detail: 'The Authorization header carried a token that does not match any active personal access token. ' \
              'It may be revoked, expired, or mistyped.',
      how_to_authenticate: HOW_TO_AUTHENTICATE
    )
  end

  # Login failure: the caller is already at the right door, so no
  # how_to_authenticate routing block.
  def render_invalid_credentials
    render_problem(
      type: :invalid_credentials, title: 'Invalid credentials', status: :unauthorized,
      detail: 'The email or password is incorrect.'
    )
  end

  # A distinct 401 for a :lockable account that has hit the failed-attempt
  # threshold (STIG AC-07). Mirrors the HTML sign-in flow, which tells a
  # locked user to wait rather than silently rejecting a correct password.
  def render_account_locked
    render_problem(
      type: :account_locked, title: 'Account locked', status: :unauthorized,
      detail: 'This account is temporarily locked due to too many failed sign-in attempts. ' \
              'Please try again later or reset your password.'
    )
  end

  # 422, not 401: the caller IS authenticated — they failed the re-verification
  # challenge. A 401 here collides with the client's session-death handling,
  # which reloads the page before any message can render.
  def render_incorrect_password
    render_problem(
      type: :incorrect_password, title: 'Incorrect password', status: :unprocessable_content,
      detail: 'Creating or managing API tokens re-verifies your identity, and the current password ' \
              'provided does not match.'
    )
  end

  # 422, not 403: the request carried no usable authenticity token for this
  # session. The caller repairs it by fetching a token (GET /api/auth/csrf)
  # and retrying once; the legacy toast extension keeps older consumers
  # rendering a message until they read the problem fields directly.
  def render_invalid_authenticity_token
    render_problem(
      type: :invalid_authenticity_token, title: 'Invalid authenticity token', status: :unprocessable_content,
      detail: 'The request carried no authenticity token, or a token that does not belong to this session. ' \
              'Fetch a fresh token from GET /api/auth/csrf, send it as X-CSRF-Token, and retry once.',
      toast: Toast.new(title: 'Request not completed', message: FORM_SESSION_EXPIRED_MESSAGE, variant: 'danger')
    )
  end

  def render_session_authentication_required
    render_problem(
      type: :session_authentication_required, title: 'Session authentication required', status: :forbidden,
      detail: 'Token management requires a signed-in browser session; API tokens cannot create or revoke tokens.'
    )
  end

  def render_ip_not_allowed
    render_problem(
      type: :ip_not_allowed, title: 'IP address not allowed', status: :forbidden,
      detail: "The request came from an IP address outside this token's allowlist."
    )
  end

  def render_insufficient_token_scope(required_scope)
    render_problem(
      type: :insufficient_token_scope, title: 'Insufficient token scope', status: :forbidden,
      detail: "This request requires the #{required_scope} scope, and the token does not grant it."
    )
  end
end
