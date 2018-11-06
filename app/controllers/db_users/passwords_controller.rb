# frozen_string_literal: true

class DbUsers::PasswordsController < Devise::PasswordsController
  # GET /resource/password/new
  def new
    super
  end

  # POST /resource/password
  def create
    super
  end

  # GET /resource/password/edit?reset_password_token=abcdef
  def edit
    super
  end

  # PUT /resource/password
  def update
    super
    if session['warden.user.db_user.key']
      session['db_user_id'] = session['warden.user.db_user.key'].first.try(:first)
    end
  end

  protected

  def after_resetting_password_path_for(resource)
    super(resource)
  end

  # The path used after sending reset password instructions
  def after_sending_reset_password_instructions_path_for(resource_name)
    super(resource_name)
  end
end
