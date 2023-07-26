# frozen_string_literal: true

# This module handles items that we use across multiple controllers
# and views throughout the application
module ApplicationHelper
  # This allows us access to the _path variables inside the application
  include Rails.application.routes.url_helpers

  # Build the links shown to users in the navigation bar
  def base_navigation
    nav_links = [
      { icon: 'mdi-folder-open-outline', name: 'Projects', link: projects_path },
      { icon: 'mdi-stamper', name: 'Released Components', link: components_path },
      { icon: 'mdi-folder', name: 'STIGs', link: stigs_path },
      { icon: 'mdi-folder', name: 'SRGs', link: srgs_path }
    ]

    if current_user&.admin? || Settings.project.create_permission_enabled
      nav_links.insert(1, { icon: 'mdi-timer-sand', name: 'Start New Project', link: new_project_path })
    end

    nav_links
  end
end
