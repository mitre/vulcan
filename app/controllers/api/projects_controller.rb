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
    # - Searches by name and email (case-insensitive)
    # - Minimum 2 characters
    # - Maximum 10 results
    #
    def search_users
      query = params[:q].to_s.strip

      if query.length < 2
        return render json: { users: [] }
      end

      # Get existing member user IDs to exclude
      existing_member_ids = @project.memberships.pluck(:user_id)

      # Search users by name or email (ILIKE for case-insensitive partial match)
      users = User.where('name ILIKE ? OR email ILIKE ?', "%#{query}%", "%#{query}%")
                  .where.not(id: existing_member_ids)
                  .limit(10)
                  .select(:id, :name, :email)
                  .order(:name)

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
