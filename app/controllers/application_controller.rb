class ApplicationController < ActionController::Base
  rescue_from DeviseLdapAuthenticatable::LdapException do |exception|
    render text: exception, status: 500
  end
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, alert: exception.message
  end
  protect_from_forgery with: :exception
  before_action :set_userstamp
  # before_action :configure_permitted_parameters, if: :devise_controller?
  helper_method :current_user

  def current_user
    if session[:db_user_id]
      @current_user ||= DbUser.find_by(id: session[:db_user_id])
    elsif session[:ldap_user_id]
      @current_user ||= LdapUser.find_by(id: session[:ldap_user_id])
    else
      session[:user_] = nil
      @current_user = nil
    end
  end

  def set_userstamp
    current_user
    User.current_user = @current_user
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :vendor, :sponsor_agency])
  end
end
