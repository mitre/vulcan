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
end
