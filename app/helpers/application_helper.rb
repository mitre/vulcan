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
      { icon: 'mdi-timer-sand', name: 'Start New Project', link: root_path },
      { icon: 'mdi-folder', name: 'SRGs', link: root_path },
      { icon: 'mdi-folder-zip-outline', name: 'Upload SRG', link: root_path }
    ]
  end

  def resource_name
    :user
  end

  def resource
    @resource ||= User.new
  end

  def devise_mapping
    @devise_mapping ||= Devise.mappings[:user]
  end
end
