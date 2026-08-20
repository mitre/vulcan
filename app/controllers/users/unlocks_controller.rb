# frozen_string_literal: true

module Users
  # Adds JSON format support to Devise account unlock flows.
  class UnlocksController < Devise::UnlocksController
    def create
      if resource_params[:email].blank?
        self.resource = resource_class.new
        resource.errors.add(:email, :blank)
        return respond_to do |format|
          format.html { respond_with(resource) }
          format.json do
            render json: {
              toast: Toast.new(
                title: 'Could not send instructions.',
                message: resource.errors.full_messages,
                variant: 'danger'
              )
            }, status: :unprocessable_content
          end
        end
      end

      self.resource = resource_class.send_unlock_instructions(resource_params)
      yield resource if block_given?

      respond_to do |format|
        if successfully_sent?(resource)
          format.html { redirect_to after_sending_unlock_instructions_path_for(resource) }
          format.json do
            render_toast(title: 'Instructions sent.',
                         message: find_message(:send_paranoid_instructions),
                         variant: 'success', status: :ok)
          end
        else
          format.html { respond_with(resource) }
          format.json do
            render json: {
              toast: Toast.new(
                title: 'Could not send instructions.',
                message: resource.errors.full_messages,
                variant: 'danger'
              )
            }, status: :unprocessable_content
          end
        end
      end
    end
  end
end
