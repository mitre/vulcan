# frozen_string_literal: true

module Users
  # This controller extends Devise to add JSON API support for email confirmation
  class ConfirmationsController < Devise::ConfirmationsController
    respond_to :html, :json

    # POST /users/confirmation - Resend confirmation instructions
    def create
      respond_to do |format|
        format.json do
          self.resource = resource_class.send_confirmation_instructions(resource_params)

          if successfully_sent?(resource)
            render json: {
              success: true,
              message: 'Confirmation instructions sent to your email'
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

    # GET /users/confirmation?confirmation_token=xxx - Confirm email
    def show
      respond_to do |format|
        format.json do
          self.resource = resource_class.confirm_by_token(params[:confirmation_token])

          if resource.errors.empty?
            sign_in(resource) # Automatically sign in after confirmation
            render json: {
              success: true,
              user: resource.as_json(only: %i[id email name admin]),
              message: 'Email confirmed successfully'
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
