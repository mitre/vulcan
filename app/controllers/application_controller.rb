# frozen_string_literal: true

# This is the base controller for the application. Things should only be
# placed here if they are shared between multiple controllers
class ApplicationController < ActionController::Base
  helper :all

  before_action :setup_navigation, :authenticate_user!

  rescue_from NotAuthorizedError, with: :not_authorized

  private

  def not_authorized(exception)
    flash.alert = exception.message # 'You are not authorized to perform this action.'
    redirect_to '/'
  end

  def setup_navigation
    @navigation = []
    @navigation += helpers.base_navigation if current_user
  end
end
