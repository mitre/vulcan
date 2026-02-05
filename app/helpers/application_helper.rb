# frozen_string_literal: true

# This module handles items that we use across multiple controllers
# and views throughout the application
module ApplicationHelper
  # This allows us access to the _path variables inside the application
  include Rails.application.routes.url_helpers

  # Build the links shown to users in the navigation bar
  def base_navigation
    nav_links = [
      { icon: 'folder2-open', name: 'Projects', link: projects_path },
      { icon: 'patch-check-fill', name: 'Released Components', link: components_path },
      { icon: 'clipboard-check', name: 'STIGs', link: stigs_path },
      { icon: 'clipboard', name: 'SRGs', link: srgs_path }
    ]

    nav_links
  end
end
