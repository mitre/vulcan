# frozen_string_literal: true

module Api
  ##
  # Server-side user search for membership flows.
  #
  # Scopes:
  #   - (default): search non-members for "add member" flow (admin only)
  #   - scope=members: search existing members for PoC selection (any member)
  #
  class UserSearchController < BaseController
    before_action :authenticate_user!
    before_action :set_target
    before_action :authorize_search

    def index
      query = params[:q].to_s.strip

      return render json: { users: [] } if query.length < 2

      limit = params.fetch(:limit, 10).to_i.clamp(1, 25)
      users = if params[:scope] == 'members'
                @target.search_members(query, limit: limit)
              else
                @target.search_available_members(query, limit: limit)
              end

      render json: { users: users.map { |u| { id: u.id, name: u.name, email: u.email } } }
    end

    private

    def set_target
      @target = case params[:membership_type]
                when 'Project'
                  Project.find(params[:membership_id])
                when 'Component'
                  Component.find(params[:membership_id])
                else
                  raise ActiveRecord::RecordNotFound
                end
    end

    def authorize_search
      if params[:scope] == 'members'
        # Any member can search within existing members (e.g., PoC selection)
        return if current_user.admin || current_user.effective_permissions(@target)

        raise NotAuthorizedError, 'You must be a member to search'
      else
        # Only admins can search for non-members (add member flow)
        return if current_user.admin || current_user.effective_permissions(@target) == 'admin'

        raise NotAuthorizedError, 'You must be an admin to search for users'
      end
    end
  end
end
