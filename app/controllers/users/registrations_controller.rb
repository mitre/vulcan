# frozen_string_literal: true

module Users
  # This controller exists so that we can block user registration if local user
  # login is disabled.
  class RegistrationsController < Devise::RegistrationsController
    before_action :configure_permitted_parameters
    # Devise's base class guards :edit/:update/:destroy with authenticate_scope!
    # (which calls authenticate_user!(force: true) for stale-session protection).
    # We must INCLUDE those originals when adding our custom settings-shell actions,
    # because prepend_before_action replaces — not extends — the parent's registration.
    prepend_before_action :authenticate_scope!, only: %i[edit update destroy edit_password edit_activity edit_tokens]

    def edit
      respond_to do |format|
        format.html { super }
        format.json do
          self.resource = send(:"authenticate_#{resource_name}!", force: true)
          render json: CurrentUserBlueprint.render(resource), status: :ok
        end
      end
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

    # Self-delete. Guards, in order:
    #   1. Continuity — the last system admin cannot remove themselves
    #      (mirrors UsersController#destroy; promote another admin first).
    #   2. Re-authentication (OWASP ASVS 3.7.1) — local-credential users must
    #      supply current_password, same as unlink_identity and email changes.
    #      Provider-managed and auto-password users are exempt: they don't
    #      know their local password and their IdP owns re-authentication.
    def destroy
      if resource.admin? && User.where(admin: true).one?
        return respond_with_error(
          'You are the only administrator. Promote another user to admin before deleting your account.',
          :unprocessable_content, title: 'Cannot delete account.'
        )
      end

      # Project admin continuity — same rule as UsersController#destroy:
      # deleting a project's only admin orphans it for its team.
      if (block_message = resource.sole_admin_deletion_block_message(subject: 'You are'))
        return respond_with_error(block_message, :unprocessable_content, title: 'Cannot delete account.')
      end

      if password_required_for_destroy? && !reauthenticated_for_destroy?
        if resource.access_locked?
          return respond_with_error('Your account has been locked due to too many failed attempts. Please try again later.',
                                    :locked, title: 'Cannot delete account.')
        end

        return respond_with_error('Incorrect password. Please enter your current password to delete your account.',
                                  :unprocessable_content, title: 'Cannot delete account.')
      end

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
      identity = current_user.identities.find_by(id: params[:identity_id])
      return respond_with_error('Identity not found.', :not_found) unless identity

      unless current_user.valid_for_authentication? { current_user.valid_password?(params[:current_password].to_s) }
        return respond_with_error('Your account has been locked due to too many failed attempts. Please try again later.', :locked) if current_user.access_locked?

        return respond_with_error('Incorrect password. Please enter your current password to unlink.', :unprocessable_content)
      end

      title = OidcProviderRegistry.title_for(identity.provider)
      current_user.unlink_identity!(identity)

      respond_to do |format|
        format.html do
          flash[:notice] = "Your #{title} identity has been unlinked."
          redirect_to edit_user_registration_path
        end
        format.json do
          render_toast(title: 'Identity unlinked.',
                       message: "#{title} identity unlinked successfully.",
                       variant: 'success', status: :ok)
        end
      end
    rescue User::IdentityGuardError => e
      respond_with_error(e.message, :unprocessable_content)
    end

    # POST /users/initiate_link — start the OmniAuth flow to link an external
    # provider to the current local-only account. Sets a session flag so the
    # OmniAuth callback attaches the identity to current_user instead of
    # creating/finding a separate account.
    def initiate_link
      provider = params[:provider].to_s

      return respond_with_error("The #{provider.upcase} provider is not enabled on this instance.", :unprocessable_content) unless provider_enabled?(provider)

      return respond_with_error("You already have a linked #{OidcProviderRegistry.title_for(provider)} identity.", :unprocessable_content) if current_user.identities.exists?(provider: provider)

      session[:link_in_progress] = true
      session[:link_provider] = provider
      redirect_to omniauth_authorize_path(:user, provider), allow_other_host: false
    end

    private

    def provider_enabled?(provider)
      Devise.omniauth_providers.include?(provider.to_sym)
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

    # Re-authentication applies only where a usable local credential exists.
    # Provider-managed users (LDAP/OIDC/GitHub) and auto-password accounts
    # (SSO-created; random password they never saw) re-authenticate at their
    # identity provider, not here.
    def password_required_for_destroy?
      resource.provider.nil? && !resource.password_automatically_set
    end

    # valid_for_authentication? wraps the password check so wrong attempts
    # count toward lockout (Devise lockable), same as unlink_identity.
    def reauthenticated_for_destroy?
      resource.valid_for_authentication? do
        resource.valid_password?(params.dig(:user, :current_password).to_s)
      end
    end

    def respond_with_error(message, status, title: 'Cannot unlink')
      respond_to do |format|
        format.html do
          flash.alert = message
          redirect_to edit_user_registration_path
        end
        format.json do
          render json: { toast: Toast.new(title: title, message: [message], variant: 'danger') },
                 status: status
        end
      end
    end

    protected

    # Field-sensitivity split (Devise design + OWASP ASVS re-authentication
    # for sensitive account changes): non-sensitive fields (name, slack)
    # save without a password; changing the EMAIL — the login identifier —
    # requires the current password. Provider-managed users never change
    # email here: the identity provider owns it.
    #
    # With email confirmation disabled (no SMTP), reconfirmable would hold
    # the new address in unconfirmed_email waiting for a mail that never
    # sends — skip_reconfirmation! applies it immediately instead (same
    # pattern as the admin path in UsersController#update).
    def update_resource(resource, params)
      if resource.password_automatically_set && password_change?(params)
        resource.password_automatically_set = false
        resource.update(params.except('current_password'))
      elsif resource.provider.nil? && email_change?(resource, params)
        resource.skip_reconfirmation! unless Settings.local_login.email_confirmation
        resource.update_with_password(params)
      elsif password_change?(params)
        resource.update_with_password(params)
      else
        resource.update_without_password(params.except('email', 'current_password'))
      end
    end

    def password_change?(params)
      params['password'].present?
    end

    def email_change?(resource, params)
      params['email'].present? && params['email'] != resource.email
    end

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: %i[name slack_user_id])
      devise_parameter_sanitizer.permit(:account_update, keys: %i[name slack_user_id email current_password])
    end
  end
end
