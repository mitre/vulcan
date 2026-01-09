# frozen_string_literal: true

module Api
  ##
  # API controller for project member management
  #
  class ProjectsController < ApplicationController
    skip_before_action :setup_navigation
    skip_before_action :check_access_request_notifications
    before_action :authenticate_user!
    before_action :set_project
    before_action :authorize_admin_project

    ##
    # GET /api/projects/:id/search_users?q=<query>
    # Search for users to invite to a project
    # - Admin-only (global admins or project admins)
    # - Excludes existing project members
    # - Slack model: Shows first 10 users by default, filters as you type
    # - Maximum 10 results
    #
    def search_users
      query = params[:q].to_s.strip

      # Get existing member user IDs to exclude
      existing_member_ids = @project.memberships.pluck(:user_id)

      # Slack model: Show first 10 users if query is empty or short
      if query.length < 2
        users = User.where.not(id: existing_member_ids)
                    .limit(10)
                    .select(:id, :name, :email)
                    .order(:name)
      else
        # Search users by name or email (ILIKE for case-insensitive partial match)
        users = User.where('name ILIKE ? OR email ILIKE ?', "%#{query}%", "%#{query}%")
                    .where.not(id: existing_member_ids)
                    .limit(10)
                    .select(:id, :name, :email)
                    .order(:name)
      end

      render json: {
        users: users.map do |user|
          {
            id: user.id,
            name: user.name,
            email: user.email
          }
        end
      }
    end

    private

    def set_project
      @project = Project.find(params[:id])
    end
  end
end
