# frozen_string_literal: true

# Single source for every JSON auth and infrastructure error body, served as
# RFC 9457 problem details (application/problem+json): a stable machine
# `type` URI anchoring into the API docs, a `title` naming the error class,
# the `status` code repeated in the body, and an occurrence-specific
# `detail` saying why. Vulcan-specific help rides as RFC extension members —
# `how_to_authenticate` on 401s, the project `admins` to ask on permission
# denials. Domain and validation feedback (the toast contract) is a separate
# channel and never flows through here.
module ErrorRendering
  extend ActiveSupport::Concern

  PROBLEM_MEDIA_TYPE = 'application/problem+json'
  # The docs-site errors page: every emitted type fragment has a matching
  # heading anchor there, enforced by a correspondence guard in the error
  # rendering request spec.
  ERROR_DOCS_BASE = '/docs/api/errors'

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

  # Pure builder for the RFC 9457 problem document. Shared by the controller
  # concern (render_problem) and the Devise failure app so both emit a
  # byte-identical envelope.
  def self.problem_document(type:, title:, status:, detail:, **extensions)
    { type: "#{ERROR_DOCS_BASE}##{type}", title: title, status: Rack::Utils.status_code(status),
      detail: detail, **extensions }
  end

  private

  def render_problem(type:, title:, status:, detail:, **extensions)
    render json: ErrorRendering.problem_document(
      type: type, title: title, status: status, detail: detail, **extensions
    ), status: status, content_type: PROBLEM_MEDIA_TYPE
  end

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

  def render_incorrect_password
    render_problem(
      type: :incorrect_password, title: 'Incorrect password', status: :unauthorized,
      detail: 'Creating or managing API tokens re-verifies your identity, and the current password ' \
              'provided does not match.'
    )
  end

  # 403 with the who-to-ask extension. The legacy toast extension keeps
  # older consumers rendering a basic toast until they read the problem
  # fields directly.
  def render_permission_denied(exception)
    project = permission_denied_project_context
    admins = project ? project.admins.map { |a| { name: a.name, email: a.email } } : []

    render_problem(
      type: :permission_denied, title: 'Permission denied', status: :forbidden,
      detail: exception.message,
      admins: admins,
      toast: Toast.new(title: 'Not Authorized.', message: exception.message, variant: 'danger')
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

  def render_not_found
    render_problem(
      type: :not_found, title: 'Not found', status: :not_found,
      detail: 'The requested resource could not be found.'
    )
  end

  def render_parameter_missing(exception)
    render_problem(
      type: :parameter_missing, title: 'Missing parameter', status: :bad_request,
      detail: exception.message
    )
  end

  def render_page_out_of_range(exception)
    render_problem(
      type: :page_out_of_range, title: 'Page out of range', status: :bad_request,
      detail: "Page #{exception.pagy.page} is out of range (1..#{exception.pagy.last})"
    )
  end

  def permission_denied_project_context
    @project || @component&.project
  end
end
