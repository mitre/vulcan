# frozen_string_literal: true

# This is the base controller for the application. Things should only be
# placed here if they are shared between multiple controllers
class ApplicationController < ActionController::Base
  helper :all

  before_action :setup_navigation, :authenticate_user!

  rescue_from NotAuthorizedError, with: :not_authorized

  def authorize_logged_in
    return unless current_user.nil?

    raise(NotAuthorizedError)
  end

  def authorize_admin
    return if current_user.admin

    raise(NotAuthorizedError, 'You are not authorized to perform administrator actions.')
  end

  def authorize_admin_project
    return if current_user&.can_admin_project?(@project)

    raise(NotAuthorizedError, 'You are not authorized to perform administrator actions on this project')
  end

  def authorize_author_project
    return if current_user&.can_author_project?(@project)

    raise(NotAuthorizedError, 'You are not authorized to perform author actions on this project')
  end

  def authorize_review_project
    return if current_user&.can_review_project?(@project)

    raise(NotAuthorizedError, 'You are not authorized to perform reviewer actions on this project')
  end

  private

  def not_authorized(exception)
    # Based on the accepted response type, either send a JSON response with the
    # alert message, or redirect to home and display the alert.
    respond_to do |format|
      format.html do
        flash.alert = exception.message
        redirect_to '/'
      end
      format.json do
        render json: {
          toast: {
            title: 'Not Authorized.',
            message: exception.message,
            variant: 'danger'
          }
        }, status: :unauthorized
      end
    end
  end

  def setup_navigation
    @navigation = []
    @navigation += helpers.base_navigation if current_user
    @navigation += helpers.admin_navigation if current_user&.admin?
  end
end
