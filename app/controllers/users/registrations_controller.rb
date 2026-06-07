# frozen_string_literal: true

module Users
  # This controller exists so that we can block user registration if local user
  # login is disabled.
  class RegistrationsController < Devise::RegistrationsController
    before_action :configure_permitted_parameters
    # Devise's stock `authenticate_scope!` only guards :edit / :update /
    # :destroy. The settings-shell sub-pages we add (#edit_password,
    # #edit_activity) need the same protection.
    prepend_before_action :authenticate_scope!, only: %i[edit_password edit_activity edit_tokens]

    def edit
      super
    end

    # GET /users/edit/password — Change Password sub-page of the
    # settings shell. Renders a Vue page (UserPasswordPage) that
    # PUTs to /users on save (same endpoint as profile updates).
    def edit_password
      self.resource = current_user
    end

    # GET /users/edit/activity — Activity sub-page of the settings
    # shell. Loads the user's audit trail (Audited::Audit polymorphism
    # requires filtering on BOTH user_id AND user_type to avoid matching
    # non-User actors that share a numeric id, e.g. 'System' background
    # job entries).
    def edit_tokens
      self.resource = current_user
    end

    def edit_activity
      self.resource = current_user
      @histories = AuditBlueprint.render_as_json(
        Audited.audit_class.includes(:user)
               .where(user_id: current_user.id, user_type: 'User')
               .order(created_at: :desc)
               .limit(50)
      )
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
      prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)

      resource_updated = update_resource(resource, account_update_params)

      if resource_updated
        flash_msg = update_flash_message(resource, prev_unconfirmed_email)
        respond_to do |format|
          format.html do
            bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?
            flash[:notice] = flash_msg
            redirect_to after_update_path_for(resource)
          end
          format.json do
            render_toast(title: 'Account updated.',
                         message: flash_msg,
                         variant: 'success', status: :ok)
          end
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
              toast: Toast.new(
                title: 'Could not update profile.',
                message: resource.errors.full_messages,
                variant: 'danger'
              )
            }, status: :unprocessable_content
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
        format.json do
          render_toast(title: 'Account deleted.',
                       message: 'Account deleted successfully.',
                       variant: 'success', status: :ok)
        end
      end
    end

    # Unlink the external identity (OIDC/LDAP/GitHub) from the current user's account.
    # Reverts the account to local-only. Requires current password verification to:
    #   1. Prove account ownership (prevents CSRF/session-hijack attacks)
    #   2. Prove the user can still authenticate after unlink (prevents lockout)
    # Refused when local login is globally disabled (no fallback auth method).
    def unlink_identity
      user = current_user

      return respond_with_error('Nothing to unlink — this account has no linked identity.', :unprocessable_content) if user.provider.blank?

      unless Settings.local_login.enabled
        return respond_with_error(
          'Cannot unlink: local login is disabled on this instance. ' \
          'Unlinking would lock you out of your account.',
          :unprocessable_content
        )
      end

      unless user.valid_for_authentication? { user.valid_password?(params[:current_password].to_s) }
        return respond_with_error('Your account has been locked due to too many failed attempts. Please try again later.', :locked) if user.access_locked?

        return respond_with_error('Incorrect password. Please enter your current password to unlink.', :unprocessable_content)
      end

      previous_provider = user.provider
      user.audit_comment = "Unlinked #{previous_provider.upcase} identity"
      user.update!(provider: nil, uid: nil, failed_attempts: 0)
      Rails.logger.info "AUDIT: Unlinked #{previous_provider} identity from #{user.email}"

      respond_to do |format|
        format.html do
          flash[:notice] = "Your #{previous_provider.upcase} identity has been unlinked. " \
                           'You can now sign in with your email and password only.'
          redirect_to edit_user_registration_path
        end
        format.json do
          render_toast(title: 'Identity unlinked.',
                       message: "#{previous_provider.upcase} identity unlinked successfully.",
                       variant: 'success', status: :ok)
        end
      end
    end

    # POST /users/initiate_link — start the OmniAuth flow to link an external
    # provider to the current local-only account. Sets a session flag so the
    # OmniAuth callback attaches the identity to current_user instead of
    # creating/finding a separate account.
    def initiate_link
      user = current_user
      provider = params[:provider].to_s

      return respond_with_error('Your account already has a linked identity. Unlink it first to link a different provider.', :unprocessable_content) if user.provider.present?

      return respond_with_error("The #{provider.upcase} provider is not enabled on this instance.", :unprocessable_content) unless provider_enabled?(provider)

      session[:link_in_progress] = true
      session[:link_provider] = provider
      redirect_to user_oidc_omniauth_authorize_path, allow_other_host: false
    end

    private

    def provider_enabled?(provider)
      case provider
      when 'oidc' then Settings.respond_to?(:oidc) && Settings.oidc&.enabled
      when 'ldap' then Settings.respond_to?(:ldap) && Settings.ldap&.enabled
      when 'github' then Settings.respond_to?(:github) && Settings.github&.enabled
      else false
      end
    end

    # Devise stock behavior: if the user changed their email and reconfirmation
    # is required, tell them a confirmation link was sent. Otherwise, generic message.
    def update_flash_message(resource, prev_unconfirmed_email)
      if resource.respond_to?(:unconfirmed_email) && resource.unconfirmed_email.present? &&
         resource.unconfirmed_email != prev_unconfirmed_email
        "A confirmation link has been sent to #{resource.unconfirmed_email}. " \
          'Please follow the link to verify your new email address.'
      else
        'Profile updated successfully.'
      end
    end

    def respond_with_error(message, status)
      respond_to do |format|
        format.html do
          flash.alert = message
          redirect_to edit_user_registration_path
        end
        format.json do
          render json: { toast: Toast.new(title: 'Cannot unlink', message: [message], variant: 'danger') },
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
