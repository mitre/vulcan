# frozen_string_literal: true

module Users
  # This controller exists so that we can block user registration if local user
  # login is disabled.
  class RegistrationsController < Devise::RegistrationsController
    before_action :configure_permitted_parameters

    def edit
      # Load user's audit history for the activity panel
      @histories = Audited.audit_class.includes(:user)
                          .where(user_id: current_user.id)
                          .order(created_at: :desc)
                          .limit(50)
                          .map(&:format)
      super
    end

    def create
      if Settings.local_login.enabled
        super
      else
        redirect_back(fallback_location: new_user_session_path, alert: I18n.t('devise.registrations.disabled'))
      end
    end

    def update
      self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
      resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)

      resource_updated = update_resource(resource, account_update_params)

      if resource_updated
        respond_to do |format|
          format.html do
            bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?
            flash[:notice] = 'Profile updated successfully.'
            redirect_to after_update_path_for(resource)
          end
          format.json { render json: { toast: 'Profile updated successfully.' } }
        end
      else
        respond_to do |format|
          format.html do
            clean_up_passwords resource
            set_minimum_password_length
            respond_with resource
          end
          format.json do
            render json: {
              toast: {
                title: 'Could not update profile.',
                message: resource.errors.full_messages,
                variant: 'danger'
              }
            }, status: :unprocessable_entity
          end
        end
      end
    end

    def destroy
      resource.destroy
      Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)

      respond_to do |format|
        format.html do
          flash[:notice] = 'Your account has been successfully deleted.'
          redirect_to root_path
        end
        format.json { render json: { toast: 'Account deleted successfully.' } }
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
