# frozen_string_literal: true

module Admin
  # Admin controller for user management.
  # Provides user listing, detail view, and security actions.
  # Supports server-side pagination and filtering for large user bases.
  class UsersController < BaseController
    before_action :set_user, only: %i[show update destroy lock unlock reset_password resend_confirmation]

    # GET /admin/users
    # Supports pagination and filtering:
    #   - page, per_page: pagination
    #   - search: name/email search
    #   - provider: 'local' or 'external'
    #   - role: 'admin' or 'user'
    #   - status: 'active', 'locked', or 'unconfirmed'
    def index
      @users = apply_filters(User.alphabetical)

      respond_to do |format|
        format.html # renders SPA layout
        format.json { render json: users_json_with_pagination }
      end
    end

    # GET /admin/users/:id
    def show
      respond_to do |format|
        format.html { redirect_to admin_users_path }
        format.json { render json: user_detail_json }
      end
    end

    # POST /admin/users/:id/lock
    def lock
      if @user.access_locked?
        render json: { error: 'Account is already locked' }, status: :unprocessable_entity
        return
      end

      @user.lock_access!(send_instructions: false)
      render json: { toast: "#{@user.name}'s account has been locked.", user: user_summary_json(@user) }
    end

    # POST /admin/users/:id/unlock
    def unlock
      unless @user.access_locked?
        render json: { error: 'Account is not locked' }, status: :unprocessable_entity
        return
      end

      @user.unlock_access!
      render json: { toast: "#{@user.name}'s account has been unlocked.", user: user_summary_json(@user) }
    end

    # POST /admin/users/:id/reset_password
    def reset_password
      # Only allow password reset for local users
      if @user.provider.present?
        render json: { error: 'Cannot reset password for external authentication users' }, status: :unprocessable_entity
        return
      end

      @user.send_reset_password_instructions
      render json: { toast: "Password reset email sent to #{@user.email}." }
    end

    # POST /admin/users/:id/resend_confirmation
    def resend_confirmation
      if @user.confirmed?
        render json: { error: 'User email is already confirmed' }, status: :unprocessable_entity
        return
      end

      @user.send_confirmation_instructions
      render json: { toast: "Confirmation email resent to #{@user.email}." }
    end

    # POST /admin/users/invite
    def invite
      email = invite_params[:email]
      name = invite_params[:name]

      # Check if user already exists
      existing_user = User.find_by(email: email.downcase)
      if existing_user
        render json: { error: 'A user with this email already exists' }, status: :unprocessable_entity
        return
      end

      # Create invited user with random password
      user = User.new(
        email: email,
        name: name,
        password: Devise.friendly_token
      )

      if user.save
        # Send confirmation email
        user.send_confirmation_instructions

        render json: {
          toast: "Invitation sent to #{email}.",
          user: user_summary_json(user)
        }, status: :created
      else
        render json: {
          error: 'Failed to create user',
          details: user.errors.full_messages
        }, status: :unprocessable_entity
      end
    end

    # PATCH /admin/users/:id
    def update
      if @user.update(update_params)
        render json: {
          toast: "#{@user.name}'s account has been updated.",
          user: user_summary_json(@user)
        }
      else
        render json: {
          error: 'Failed to update user',
          details: @user.errors.full_messages
        }, status: :unprocessable_entity
      end
    end

    # DELETE /admin/users/:id
    def destroy
      # Prevent self-deletion
      if @user.id == current_user.id
        render json: { error: 'Cannot delete your own account' }, status: :unprocessable_entity
        return
      end

      user_name = @user.name
      @user.destroy

      render json: { toast: "#{user_name}'s account has been deleted." }
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def invite_params
      params.expect(user: %i[email name])
    end

    def update_params
      params.expect(user: %i[name email admin])
    end

    # Apply filters and return paginated scope
    def apply_filters(scope)
      # Search by name or email
      if params[:search].present?
        search_term = "%#{params[:search].downcase}%"
        scope = scope.where('LOWER(name) LIKE ? OR LOWER(email) LIKE ?', search_term, search_term)
      end

      # Filter by provider type
      case params[:provider]
      when 'local'
        scope = scope.where(provider: [nil, ''])
      when 'external'
        scope = scope.where.not(provider: [nil, ''])
      end

      # Filter by role
      case params[:role]
      when 'admin'
        scope = scope.where(admin: true)
      when 'user'
        scope = scope.where(admin: false)
      end

      # Filter by status
      case params[:status]
      when 'locked'
        scope = scope.where.not(locked_at: nil)
      when 'unconfirmed'
        scope = scope.where(confirmed_at: nil)
      when 'active'
        scope = scope.where(locked_at: nil).where.not(confirmed_at: nil)
      end

      scope
    end

    def users_json_with_pagination
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 25).to_i.clamp(10, 100)
      total = @users.count
      paginated_users = @users.offset((page - 1) * per_page).limit(per_page)

      {
        users: paginated_users.map { |u| user_summary_json(u) },
        pagination: {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: (total.to_f / per_page).ceil
        }
      }
    end

    def users_json
      {
        users: @users.map { |u| user_summary_json(u) }
      }
    end

    def user_summary_json(user)
      {
        id: user.id,
        name: user.name,
        email: user.email,
        provider: user.provider.presence || 'local',
        admin: user.admin,
        locked: user.access_locked?,
        confirmed: user.confirmed?,
        sign_in_count: user.sign_in_count,
        last_sign_in_at: user.last_sign_in_at,
        created_at: user.created_at
      }
    end

    def user_detail_json
      {
        user: {
          id: @user.id,
          name: @user.name,
          email: @user.email,
          provider: @user.provider,
          admin: @user.admin,
          created_at: @user.created_at,
          updated_at: @user.updated_at,

          # Sign-in stats (trackable)
          sign_in_count: @user.sign_in_count,
          current_sign_in_at: @user.current_sign_in_at,
          last_sign_in_at: @user.last_sign_in_at,
          current_sign_in_ip: @user.current_sign_in_ip,
          last_sign_in_ip: @user.last_sign_in_ip,

          # Account status (confirmable + lockable)
          confirmed: @user.confirmed?,
          confirmed_at: @user.confirmed_at,
          locked: @user.access_locked?,
          locked_at: @user.locked_at,
          failed_attempts: @user.failed_attempts,

          # Memberships summary
          memberships: @user.memberships.includes(membership: :memberships).map do |m|
            {
              id: m.id,
              role: m.role,
              type: m.membership_type,
              name: m.membership&.name,
              membership_id: m.membership_id,
              created_at: m.created_at
            }
          end
        }
      }
    end
  end
end
