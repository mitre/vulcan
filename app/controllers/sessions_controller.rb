# frozen_string_literal: true

# Custom sessions controller to handle OIDC logout
class SessionsController < Devise::SessionsController
  def destroy
    id_token = session[:id_token]
    stored_location = stored_location_for(:user)
    
    # Clear local session
    super
    
    # If using OIDC and we have an ID token, redirect to OIDC logout
    if Settings.oidc.enabled && id_token.present?
      # Build OIDC logout URL
      oidc_config = Rails.application.config_for(:oidc)
      logout_url = build_oidc_logout_url(oidc_config, id_token)
      
      # Clear the ID token from session
      session.delete(:id_token)
      
      # Redirect to OIDC provider logout
      redirect_to logout_url, allow_other_host: true
    else
      # For non-OIDC or when no ID token, use default behavior
      redirect_to stored_location || root_path
    end
  end
  
  private
  
  def build_oidc_logout_url(config, id_token)
    base_url = config['issuer_url'].to_s
    logout_endpoint = base_url.end_with?('/') ? 'logout' : '/logout'
    post_logout_uri = config['app_url'] || root_url
    
    # Build logout URL with ID token hint and post-logout redirect
    params = {
      id_token_hint: id_token,
      post_logout_redirect_uri: post_logout_uri
    }
    
    "#{base_url}#{logout_endpoint}?#{params.to_query}"
  end
end