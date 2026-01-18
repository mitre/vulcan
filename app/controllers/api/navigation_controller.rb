# frozen_string_literal: true

module Api
  ##
  # API controller for navigation data
  # Returns navigation links and access request notifications
  #
  class NavigationController < BaseController
    def show
      links = build_navigation_links
      access_requests = build_access_requests

      render json: {
        links: links,
        access_requests: access_requests
      }
    end

    private

    def build_navigation_links
      return [] unless current_user

      [
        { icon: 'folder2-open', name: 'Projects', link: '/projects' },
        { icon: 'patch-check-fill', name: 'Released Components', link: '/components' },
        { icon: 'clipboard-check', name: 'STIGs', link: '/stigs' },
        { icon: 'clipboard', name: 'SRGs', link: '/srgs' }
      ]
    end

    def build_access_requests
      return [] unless current_user

      requests = []
      current_user.available_projects.each do |project|
        next unless current_user.can_admin_project?(project)

        project.access_requests.eager_load(:user, :project).find_each do |request|
          requests << {
            id: request.id,
            user: {
              id: request.user.id,
              name: request.user.name,
              email: request.user.email
            },
            project: {
              id: request.project.id,
              name: request.project.name
            },
            created_at: request.created_at
          }
        end
      end
      requests
    end
  end
end
