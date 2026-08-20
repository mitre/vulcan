# frozen_string_literal: true

module Api
  # App shell data for SPA navbar: nav links, access request notifications, locked users.
  class NavigationController < BaseController
    def show
      render json: {
        nav_links: nav_links,
        access_requests: access_requests,
        locked_users: locked_users
      }
    end

    private

    # This menu is also declared by ApplicationHelper#base_navigation for the
    # HAML navbar — two sources for one navigation. A request-spec tripwire
    # asserts the documentation entries agree until they are unified.
    def nav_links
      [
        { icon: 'folder2-open', name: 'Projects', link: '/projects' },
        { icon: 'patch-check-fill', name: 'Released Components', link: '/components' },
        { icon: 'clipboard-check', name: 'STIGs', link: '/stigs' },
        { icon: 'clipboard', name: 'SRGs', link: '/srgs' },
        # One top-level entry for the documentation site. Its predecessor was
        # a single-child dropdown whose link ('/disa_guide') never matched the
        # hyphenated route, so it had been broken since it was written.
        { icon: 'book', name: 'Documentation', link: '/docs' }
      ]
    end

    def access_requests
      return [] unless current_user.admin? || admin_project_ids.any?

      pending = if current_user.admin?
                  ProjectAccessRequest.eager_load(:user, :project)
                else
                  ProjectAccessRequest.where(project_id: admin_project_ids).eager_load(:user, :project)
                end

      pending.map do |ar|
        {
          id: ar.id,
          user: UserBlueprint.render_as_json(ar.user),
          project: { id: ar.project.id, name: ar.project.name }
        }
      end
    end

    def locked_users
      return [] unless current_user.admin? && Settings.lockout&.enabled

      UserBlueprint.render_as_json(User.where.not(locked_at: nil).limit(100))
    end

    def admin_project_ids
      @admin_project_ids ||= Membership.where(
        user_id: current_user.id, role: 'admin', membership_type: 'Project'
      ).pluck(:membership_id)
    end
  end
end
