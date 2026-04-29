# frozen_string_literal: true

# Specialized project blueprint for the index page that includes per-user
# computed fields (admin, is_member, access_request_id). These require
# the current_user to be passed via options.
#
# Usage: ProjectIndexBlueprint.render(projects, current_user: current_user)
class ProjectIndexBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :description, :visibility, :memberships_count,
         :admin_name, :admin_email, :created_at, :updated_at

  association :memberships, blueprint: MembershipBlueprint do |project, _options|
    project.memberships
  end

  field :admin do |project, options|
    user = options[:current_user]
    next false unless user

    project.memberships.any? { |m| m.role == 'admin' && m.user_id == user.id }
  end

  field :is_member do |project, options|
    user = options[:current_user]
    next false unless user
    next true if user.admin?

    project.memberships.any? { |m| m.user_id == user.id }
  end

  field :access_request_id do |project, options|
    user = options[:current_user]
    next nil unless user

    # Use pre-loaded hash if available, otherwise query
    ar_hash = options[:access_requests_by_project]
    if ar_hash
      ar_hash[project.id]&.id
    else
      user.access_requests.find_by(project_id: project.id)&.id
    end
  end

  # Pending top-level comment count across this project's components.
  # Surfaces a "N pending" badge on the projects-list row so admins
  # discover the triage queue without drilling into every component.
  # Counts are pre-batched via Project.pending_comment_counts.
  field :pending_comment_count do |project, options|
    counts = options[:pending_comment_counts] || {}
    counts[project.id] || 0
  end

  # Resolved deep-link target for the "Comments" badge — computed
  # server-side so the click bypasses any intermediate page.
  # - exactly 1 component with pending → /components/:id#comments
  # - multiple components with pending → /projects/:id#comments
  # - none → null (frontend renders an em-dash)
  field :pending_comment_link do |project, options|
    counts = options[:pending_comment_counts] || {}
    next nil if (counts[project.id] || 0).zero?

    targets = options[:pending_comment_target_components] || {}
    component_id = targets[project.id]
    component_id ? "/components/#{component_id}#comments" : "/projects/#{project.id}#comments"
  end
end
