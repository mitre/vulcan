# frozen_string_literal: true

module Users
  # This controller exists so that we can block user registration if local user
  # login is disabled. Also handles profile updates for Vue SPA.
  class RegistrationsController < Devise::RegistrationsController
    before_action :configure_permitted_parameters
    respond_to :html, :json

    # GET /users/edit - Profile page (JSON returns current user data)
    def edit
      respond_to do |format|
        format.json { render json: { user: resource.as_json(only: %i[id email name admin slack_user_id provider]) } }
        format.html { super }
      end
    end

    # PUT /users - Update profile
    def update
      respond_to do |format|
        format.json do
          self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
          prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)

          resource_updated = update_resource(resource, account_update_params)

          if resource_updated
            bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?
            render json: {
              success: true,
              user: resource.as_json(only: %i[id email name admin slack_user_id provider]),
              toast: 'Profile updated successfully'
            }
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

    def create
      unless Settings.local_login.enabled
        respond_to do |format|
          format.json { render json: { error: I18n.t('devise.registrations.disabled') }, status: :forbidden }
          format.html { redirect_back(fallback_location: new_user_session_path, alert: I18n.t('devise.registrations.disabled')) }
        end
        return
      end

      # Handle JSON requests for Vue SPA
      respond_to do |format|
        format.json do
          build_resource(sign_up_params)

          if resource.save
            sign_up(resource_name, resource)
            render json: { success: true, user: resource.as_json(only: %i[id email name admin]) }, status: :created
          else
            render json: { success: false, errors: resource.errors.full_messages, error: resource.errors.full_messages.join(', ') }, status: :unprocessable_entity
          end
        end
        format.html { super }
      end
    end

    protected

    def update_resource(resource, params)
      if resource.provider.nil?
        super
      else
        resource.update_without_password(params)
      end
    end

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: %i[name slack_user_id])
      devise_parameter_sanitizer.permit(:account_update, keys: %i[name slack_user_id])
    end
  end
end
