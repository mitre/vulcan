# frozen_string_literal: true

# Devise failure app that answers JSON / non-navigational auth failures with
# the RFC 9457 problem envelope naming the TRUE cause. Warden throws during
# request authentication (a superseded session, a timeout, or a plain
# unauthenticated request) carry a cause symbol as their message; at that
# point the cause is known definitively, so the body can say "signed in from
# another location" instead of a generic message. HTML / navigational
# requests fall through to Devise's default redirect + flash, unchanged.
#
# Shares its problem-document builder, how_to_authenticate block, and
# not-authenticated copy with ErrorRendering (the controller-side concern) so
# the two surfaces never drift.
class SessionAwareFailureApp < Devise::FailureApp
  # Per-cause problem content. Any cause not listed here (including nil and
  # future warden symbols) falls back to the shared not-authenticated body.
  CAUSES = {
    session_limited: {
      type: :session_superseded,
      title: 'Session ended — signed in elsewhere',
      detail: 'You were signed out because this account signed in from another location. ' \
              'Only one active session per account is allowed at a time.'
    },
    timeout: {
      type: :session_timed_out,
      title: 'Session timed out',
      detail: 'Your session timed out after a period of inactivity. Sign in again to continue.'
    }
  }.freeze

  # Build the RFC 9457 problem document for a warden failure cause. Public so
  # the cause → document mapping is unit-testable without a full Rack env.
  def self.problem_for(message)
    cause = CAUSES.fetch(message&.to_sym) do
      { type: :not_authenticated, title: 'Not authenticated', detail: ErrorRendering::NOT_AUTHENTICATED_DETAIL }
    end
    ErrorRendering.problem_document(
      type: cause[:type], title: cause[:title], status: :unauthorized,
      detail: cause[:detail], how_to_authenticate: ErrorRendering::HOW_TO_AUTHENTICATE
    )
  end

  def respond
    if problem_response?
      render_problem
    else
      super
    end
  end

  private

  # Non-navigational (JSON/API) or XHR requests get the problem body; HTML
  # navigational requests fall through to Devise's redirect + flash. Mirrors
  # Devise::FailureApp#http_auth? so the split is identical to the default.
  def problem_response?
    request.xhr? || (request_format && !is_navigational_format?) || false
  end

  def render_problem
    self.status = 401
    self.content_type = ErrorRendering::PROBLEM_MEDIA_TYPE
    self.response_body = self.class.problem_for(warden_message).to_json
  end
end
