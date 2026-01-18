# frozen_string_literal: true

module Users
  # This controller extends Devise to add JSON API support for password reset
  class PasswordsController < Devise::PasswordsController
    respond_to :html, :json

    # GET /users/password/edit?reset_password_token=xxx - Validate token
    def edit
      respond_to do |format|
        format.json do
          # Validate the token by attempting to find the user
          self.resource = resource_class.with_reset_password_token(params[:reset_password_token])

          if resource.present? && resource.reset_password_period_valid?
            render json: {
              valid: true,
              message: 'Token is valid'
            }, status: :ok
          else
            render json: {
              valid: false,
              error: 'Invalid or expired reset password token'
            }, status: :unprocessable_entity
          end
        end
        format.html { super }
      end
    end

    # PUT /users/password - Reset password with token
    def update
      respond_to do |format|
        format.json do
          self.resource = resource_class.reset_password_by_token(resource_params)

          if resource.errors.empty?
            # Unlock account if it was locked
            resource.unlock_access! if unlockable?(resource)

            # Sign in the user after password reset
            sign_in(resource_name, resource)

            render json: {
              success: true,
              user: resource.as_json(only: %i[id email name admin]),
              message: 'Password changed successfully'
            }, status: :ok
          else
            render json: {
              success: false,
              errors: resource.errors.full_messages,
              error: resource.errors.full_messages.join(', ')
            }, status: :unprocessable_entity
          end
        end
        format.html { super }
      end
    end
  end
end
