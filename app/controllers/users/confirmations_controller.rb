# frozen_string_literal: true

module Users
  # Adds JSON format support to Devise confirmation flows.
  class ConfirmationsController < Devise::ConfirmationsController
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

      self.resource = resource_class.send_confirmation_instructions(resource_params)
      yield resource if block_given?

      respond_to do |format|
        if successfully_sent?(resource)
          format.html { redirect_to after_resending_confirmation_instructions_path_for(resource_name) }
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
