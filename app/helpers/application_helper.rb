# frozen_string_literal: true

# This module handles items that we use across multiple controllers
# and views throughout the application
module ApplicationHelper
  # This allows us access to the _path variables inside the application
  include Rails.application.routes.url_helpers

  # Build the links shown to users in the navigation bar
  def base_navigation
    [
      { icon: 'mdi-folder-open-outline', name: 'Projects', link: projects_path },
      { icon: 'mdi-timer-sand', name: 'Start New Project', link: root_path }
    ]
  end

  def admin_navigation
    [
      { icon: 'mdi-folder', name: 'SRGs', link: srgs_path }
    ]
  end
end
