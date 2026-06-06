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

    def nav_links
      [
        { icon: 'folder2-open', name: 'Projects', link: '/projects' },
        { icon: 'patch-check-fill', name: 'Released Components', link: '/components' },
        { icon: 'clipboard-check', name: 'STIGs', link: '/stigs' },
        { icon: 'clipboard', name: 'SRGs', link: '/srgs' },
        { icon: 'journal-bookmark-fill', name: 'Resources', children: [
          { icon: 'book', name: 'DISA Process Guide', link: '/disa_guide' }
        ] }
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
          user: UserBlueprint.render_as_hash(ar.user),
          project: { id: ar.project.id, name: ar.project.name }
        }
      end
    end

    def locked_users
      return [] unless current_user.admin? && Settings.lockout&.enabled

      UserBlueprint.render_as_hash(User.where.not(locked_at: nil).limit(100))
    end

    def admin_project_ids
      @admin_project_ids ||= Membership.where(
        user_id: current_user.id, role: 'admin', membership_type: 'Project'
      ).pluck(:membership_id)
    end
  end
end
