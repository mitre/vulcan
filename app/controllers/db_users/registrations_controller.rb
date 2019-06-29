# frozen_string_literal: true

class DbUsers::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  def new
    super
  end

  # POST /resource
  def create
    super
    if session['warden.user.db_user.key']
      session['db_user_id'] = session['warden.user.db_user.key'].first.try(:first)
    end
    check_for_admin
  end

  # GET /resource/edit
  def edit
    super
  end

  # PUT /resource
  def update
    super
  end

  # DELETE /resource
  def destroy
    super
  end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  def cancel
    super
  end

  protected

  # If you have extra params to permit, append them to the sanitizer.
  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute, :remember_me, :api_key])
  end

  # If you have extra params to permit, append them to the sanitizer.
  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  end

  # The path used after sign up.
  def after_sign_up_path_for(resource)
    super(resource)
  end

  # The path used after sign up for inactive accounts.
  def after_inactive_sign_up_path_for(resource)
    super(resource)
  end

  private

  # make first user an admin
  def check_for_admin
    if DbUser.find(session['db_user_id']) == DbUser.first
      unless DbUser.find(session['db_user_id']).has_role? :admin
        DbUser.find(session['db_user_id']).add_role :admin
      end
    end
  end

  def set_api_key
    params[:db_user][:api_key] = SecureRandom.urlsafe_base64
  end
end
