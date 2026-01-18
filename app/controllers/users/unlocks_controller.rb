# frozen_string_literal: true

module Users
  # This controller extends Devise to add JSON API support for account unlocking
  class UnlocksController < Devise::UnlocksController
    respond_to :html, :json

    # POST /users/unlock - Resend unlock instructions
    def create
      respond_to do |format|
        format.json do
          self.resource = resource_class.send_unlock_instructions(resource_params)

          if successfully_sent?(resource)
            render json: {
              success: true,
              message: 'Unlock instructions sent to your email'
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

    # GET /users/unlock?unlock_token=xxx - Unlock account
    def show
      respond_to do |format|
        format.json do
          self.resource = resource_class.unlock_access_by_token(params[:unlock_token])

          if resource.errors.empty?
            sign_in(resource) # Automatically sign in after unlocking
            render json: {
              success: true,
              user: resource.as_json(only: %i[id email name admin]),
              message: 'Account unlocked successfully'
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
