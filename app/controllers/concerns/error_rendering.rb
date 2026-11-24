# frozen_string_literal: true

# Single source for every JSON auth and infrastructure error body, served as
# RFC 9457 problem details (application/problem+json): a stable machine
# `type` URI anchoring into the API docs, a `title` naming the error class,
# the `status` code repeated in the body, and an occurrence-specific
# `detail` saying why. Vulcan-specific help rides as RFC extension members —
# `how_to_authenticate` on 401s, the project `admins` to ask on permission
# denials. This concern owns the envelope (problem_document, render_problem)
# and the resource problems; AuthenticationErrorRendering owns the
# authentication problems and renders through the same envelope. Domain and
# validation feedback (the toast contract) is a separate channel and never
# flows through here.
module ErrorRendering
  extend ActiveSupport::Concern

  PROBLEM_MEDIA_TYPE = 'application/problem+json'
  # The docs-site errors page: every emitted type fragment has a matching
  # heading anchor there, enforced by a correspondence guard in the error
  # rendering request spec.
  ERROR_DOCS_BASE = '/docs/api/errors'

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
