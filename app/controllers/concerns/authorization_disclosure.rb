# frozen_string_literal: true

# Decides whether an authorization denial may reveal that a resource exists,
# and renders the JSON denial accordingly. A hidden project is concealed —
# answered with a 404 identical to a true miss — from any caller who cannot
# otherwise discover it; discoverable projects and members get the ordinary
# 403 with who-to-ask contacts. The problem-body builders themselves live in
# ErrorRendering; this concern only chooses between them.
module AuthorizationDisclosure
  extend ActiveSupport::Concern

  private

  # A denial conceals a resource's existence only from a caller who cannot
  # otherwise discover it. The denial's most specific resource decides: a
  # member (project- OR component-level) already knows it exists and gets an
  # honest 403; a stranger to a non-discoverable project gets a concealing
  # 404. A denial with no project context (site-admin and instance-global
  # actions — nothing to conceal) never conceals.
  def permission_denied_conceals_existence?
    if @component
      !component_discoverable_to_current_user?(@component)
    else
      project = permission_denied_project_context
      project.present? && !project_discoverable_to_current_user?(project)
    end
  end

  # A component reveals its existence when it is released (instance-wide
  # reference data), when its project is discoverable, or to any member
  # (effective_permissions covers project- and component-level membership).
  def component_discoverable_to_current_user?(component)
    return true if current_user&.admin?

    component.released || component.project.discoverable? ||
      current_user&.effective_permissions(component).present?
  end

  # A project reveals its existence when it is discoverable or to any of its
  # members (a project-level membership).
  def project_discoverable_to_current_user?(project)
    return true if current_user&.admin?

    project.discoverable? || current_user&.effective_permissions(project).present?
  end

  # JSON authorization-failure body honoring the disclosure policy: concealed
  # (hidden project) → 404 not_found, byte-identical to a true miss; otherwise
  # → 403 permission_denied with who-to-ask contacts. Shared by the
  # Api::BaseController rescue and the HTML controllers' JSON branch.
  def render_authorization_denied_json(exception)
    if permission_denied_conceals_existence?
      render_not_found
    else
      render_permission_denied(exception)
    end
  end
end
