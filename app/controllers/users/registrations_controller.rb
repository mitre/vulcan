# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  def new
    super
  end

  # POST /resource
  def create
    super
  end

  # GET /resource/edit
  def edit
    super
  end

  # PUT /resource
  def update
    if params['user']['profile_picture']
      uploaded_io = params['user']['profile_picture']
      puts uploaded_io.inspect
      File.open(Rails.root.join('app', 'assets', 'images', 'profile_pics', current_user.email + '.' + uploaded_io.original_filename.split('.')[1]), 'wb') do |file|
        file.write(uploaded_io.read)
      end
      current_user.update_attribute(:profile_pic_name, current_user.email + '.' + uploaded_io.original_filename.split('.')[1])
    end

    if @user.update_attributes(user_params)
      redirect_to show_user_path(current_user.id), notice: 'User was successfully updated.'
    else
      render action: 'edit'
    end
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
    devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  end

  # If you have extra params to permit, append them to the sanitizer.
  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [:attribute, :first_name, :last_name, :phone_number])
  end

  # The path used after sign up.
  def after_sign_up_path_for(resource)
    super(resource)
  end

  # The path used after sign up for inactive accounts.
  def after_inactive_sign_up_path_for(resource)
    super(resource)
  end
  
  def user_params
    # NOTE: Using `strong_parameters` gem
    params.require(:user).permit(:email, :first_name, :last_name, :phone_number, :password, :password_confirmation, :first_name, :last_name, :phone_number)
  end
end
