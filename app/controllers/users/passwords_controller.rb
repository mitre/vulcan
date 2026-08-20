# frozen_string_literal: true

module Users
  # Adds JSON format support to Devise password reset flows.
  class PasswordsController < Devise::PasswordsController
    def edit
      respond_to do |format|
        format.html { super }
        format.json do
          token = params[:reset_password_token]
          if token.blank?
            render json: { valid: false, error: 'No reset token provided.' },
                   status: :unprocessable_content
            return
          end

          user = resource_class.with_reset_password_token(token)
          if user&.reset_password_period_valid?
            render json: { valid: true, minimum_password_length: resource_class.password_length.min },
                   status: :ok
          else
            render json: { valid: false, error: 'Reset token is invalid or has expired.' },
                   status: :unprocessable_content
          end
        end
      end
    end

    def create
      if resource_params[:email].blank?
        self.resource = resource_class.new
        resource.errors.add(:email, :blank)
        return respond_with_validation_error
      end

      self.resource = resource_class.send_reset_password_instructions(resource_params)
      yield resource if block_given?

      respond_to do |format|
        if successfully_sent?(resource)
          format.html { redirect_to after_sending_reset_password_instructions_path_for(resource_name) }
          format.json do
            render_toast(title: 'Instructions sent.',
                         message: find_message(:send_paranoid_instructions),
                         variant: 'success', status: :ok)
          end
        else
          format.html { respond_with(resource) }
          format.json { respond_with_validation_error }
        end
      end
    end

    def update
      self.resource = resource_class.reset_password_by_token(resource_params)
      yield resource if block_given?

      if resource.errors.empty?
        resource.unlock_access! if unlockable?(resource)
        if sign_in_after_reset_password?
          resource.after_database_authentication
          sign_in(resource_name, resource)
        end

        respond_to do |format|
          format.html do
            flash_message = resource.active_for_authentication? ? :updated : :updated_not_active
            set_flash_message!(:notice, flash_message)
            redirect_to after_resetting_password_path_for(resource)
          end
          format.json do
            render_toast(title: 'Password reset.',
                         message: 'Your password has been changed successfully. You are now signed in.',
                         variant: 'success', status: :ok)
          end
        end
      else
        set_minimum_password_length

        respond_to do |format|
          format.html { respond_with(resource) }
          format.json { respond_with_validation_error('Could not reset password.') }
        end
      end
    end

    private

    def assert_reset_token_passed
      return if request.format.json?

      super
    end

    def sign_in_after_reset_password?
      resource_class.sign_in_after_reset_password
    end

    def unlockable?(resource)
      resource.respond_to?(:unlock_access!) &&
        resource.respond_to?(:unlock_strategy_enabled?) &&
        resource.unlock_strategy_enabled?(:email)
    end

    def respond_with_validation_error(title = 'Could not send instructions.')
      render json: {
        toast: Toast.new(
          title: title,
          message: resource.errors.full_messages,
          variant: 'danger'
        )
      }, status: :unprocessable_content
    end
  end
end
