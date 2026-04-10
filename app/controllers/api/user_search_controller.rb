# frozen_string_literal: true

module Api
  ##
  # Server-side user search for the "add member" flow.
  # Replaces the pre-loaded available_members list to prevent
  # information disclosure of the full user directory.
  #
  class UserSearchController < BaseController
    before_action :authenticate_user!
    before_action :set_and_authorize_target

    def index
      query = params[:q].to_s.strip

      return render json: { users: [] } if query.length < 2

      limit = params.fetch(:limit, 10).to_i.clamp(1, 25)
      users = @target.search_available_members(query, limit: limit)

      render json: { users: users.map { |u| { id: u.id, name: u.name, email: u.email } } }
    end

    private

    def set_and_authorize_target
      @target = case params[:membership_type]
                when 'Project'
                  Project.find(params[:membership_id])
                when 'Component'
                  Component.find(params[:membership_id])
                else
                  raise ActiveRecord::RecordNotFound
                end

      return if current_user.admin || current_user.effective_permissions(@target) == 'admin'

      raise NotAuthorizedError, 'You must be an admin to search for users'
    end
  end
end
