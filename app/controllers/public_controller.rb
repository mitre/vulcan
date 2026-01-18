# frozen_string_literal: true

# Public controller for serving the SPA shell to unauthenticated users
class PublicController < ApplicationController
  # Skip authentication - this serves public pages like login
  skip_before_action :authenticate_user!
  skip_before_action :setup_navigation
  skip_before_action :check_access_request_notifications

  def index
    # Renders the SPA shell (app/views/projects/index.html.haml)
    # Vue Router handles client-side routing
    render 'projects/index'
  end
end
