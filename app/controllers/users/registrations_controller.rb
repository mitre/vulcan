# frozen_string_literal: true

module Users
  # This controller exists so that we can block user registration if local user
  # login is disabled.
  class RegistrationsController < Devise::RegistrationsController
    before_action :configure_permitted_parameters

    def edit
      # Load user's audit history for the activity panel.
      # The `user` association on Audited::Audit is polymorphic (user_id + user_type),
      # so we must filter on BOTH to avoid matching non-User actors that might share
      # the same numeric ID (e.g. 'System' entries created by background jobs).
      @histories = Audited.audit_class.includes(:user)
                          .where(user_id: current_user.id, user_type: 'User')
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

    # Unlink the external identity (OIDC/LDAP/GitHub) from the current user's account.
    # Reverts the account to local-only. Requires current password verification to:
    #   1. Prove account ownership (prevents CSRF/session-hijack attacks)
    #   2. Prove the user can still authenticate after unlink (prevents lockout)
    # Refused when local login is globally disabled (no fallback auth method).
    def unlink_identity
      user = current_user

      return respond_with_error('Nothing to unlink — this account has no linked identity.', :unprocessable_entity) if user.provider.blank?

      unless Settings.local_login.enabled
        return respond_with_error(
          'Cannot unlink: local login is disabled on this instance. ' \
          'Unlinking would lock you out of your account.',
          :unprocessable_entity
        )
      end

      return respond_with_error('Incorrect password. Please enter your current password to unlink.', :unprocessable_entity) unless user.valid_password?(params[:current_password].to_s)

      previous_provider = user.provider
      # Atomic update: both fields must be cleared together to satisfy the
      # partial unique index on (provider, uid) WHERE both are not null.
      # audit_comment is captured by the `audited` gem and used as the human-readable
      # label in the activity panel instead of the raw "provider was updated..." text.
      user.audit_comment = "Unlinked #{previous_provider.upcase} identity"
      user.update!(provider: nil, uid: nil)
      Rails.logger.info "AUDIT: Unlinked #{previous_provider} identity from #{user.email}"

      respond_to do |format|
        format.html do
          flash[:notice] = "Your #{previous_provider.upcase} identity has been unlinked. " \
                           'You can now sign in with your email and password only.'
          redirect_to edit_user_registration_path
        end
        format.json do
          render json: { toast: "#{previous_provider.upcase} identity unlinked successfully." }
        end
      end
    end

    private

    def respond_with_error(message, status)
      respond_to do |format|
        format.html do
          flash.alert = message
          redirect_to edit_user_registration_path
        end
        format.json do
          render json: { toast: { title: 'Cannot unlink', message: [message], variant: 'danger' } },
                 status: status
        end
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
