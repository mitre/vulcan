class ApplicationController < ActionController::Base
  rescue_from DeviseLdapAuthenticatable::LdapException do |exception|
    render text: exception, status: 500
  end
  protect_from_forgery with: :exception
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

  protected

  #make first user an admin
  def check_for_admin
    if current_user && User.first == User.last
      unless current_user.has_role? :admin
        current_user.add_role :admin
      end
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :vendor, :sponsor_agency])
  end
end
