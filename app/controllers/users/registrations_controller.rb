# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  def new!
    puts "here"
    super
  end

  # POST /resource
  def create!
    super
    # puts vendor_params
    # if params['type'] == 'Sponsor'
    #   sponsor = SponsorAgency.where("'sponsor_name' = ? AND 'phone_number' = ? AND 'email' = ? AND 'organization' = ?",
    #                       sponsor_params['sponsor_name'], sponsor_params['phone_number'], sponsor_params['email'], sponsor_params['organization'] )
    #   current_user.sponsor_agency = SponsorAgency.new(sponsor_params) unless sponsor.exists
    #   current_user.sponsor_agency = sponsor if sponsor.exists
    #   current_user.requests.create({status: 'Pending', role: 'sponsor'})
    # else
    #   vendor = Vendor.where("'vendor_name' = ? AND 'point_of_contact' = ? AND 'poc_email' = ? AND 'poc_phone_number' = ?",
    #         vendor_params['vendor_name'], vendor_params['point_of_contact'], vendor_params['poc_email'], vendor_params['poc_phone_number'])
    #   current_user.vendor = Vendor.new(vendor_params) unless vendor.exists
    #   current_user.vendor = vendor if vendor.exists  
    #   current_user.requests.create({status: 'Pending', role: 'vendor'})
    # end
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
  
  def set_role
    if current_user.has_role? :admin
      user = User.find(params['user_id'])
      if !user.roles.blank?
        user.remove_role user.roles.first.name
      end
      user.add_role params['org'].split('-')[1]
      user.vendors << Vendor.find(params['org'].split('-')[0]) if params['org'].split('-')[1] == 'vendor'
      user.sponsor_agencies << SponsorAgency.find(params['org'].split('-')[0]) if params['org'].split('-')[1] == 'sponsor'
      redirect_to "/"
    end
  end

  protected

  # If you have extra params to permit, append them to the sanitizer.
  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute, :vendor, :sponsor_agency])
  end

  # If you have extra params to permit, append them to the sanitizer.
  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [:attribute, :first_name, :last_name, :phone_number, :vendor, :sponsor_agency])
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
