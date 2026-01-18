# frozen_string_literal: true

module Admin
  # Base controller for all admin functionality.
  # Ensures only admin users can access these endpoints.
  class BaseController < ApplicationController
    before_action :authorize_admin

    layout 'application'

    private

    # Override to provide admin-specific JSON error responses
    def render_unauthorized
      respond_to do |format|
        format.html { redirect_to root_path, alert: 'Access denied. Admin privileges required.' }
        format.json { render json: { error: 'Unauthorized' }, status: :unauthorized }
      end
    end
  end
end
