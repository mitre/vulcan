# frozen_string_literal: true

# This is the base controller for the application. Things should only be
# placed here if they are shared between multiple controllers
class ApplicationController < ActionController::Base
  helper :all
  include SlackNotificationsHelper

  before_action :setup_navigation, :authenticate_user!

  rescue_from NotAuthorizedError, with: :not_authorized

  rescue_from StandardError, with: :helpful_errors unless Rails.env.development?

  def set_project_permissions
    @effective_permissions = current_user&.effective_permissions(@project)
  end

  def set_component_permissions
    @effective_permissions = current_user&.effective_permissions(@component)
  end

  def authorize_logged_in
    return unless current_user.nil?

    raise(NotAuthorizedError)
  end

  def authorize_admin
    return if current_user.admin

    raise(NotAuthorizedError, 'You are not authorized to perform administrator actions.')
  end

  def authorize_admin_or_create_permission_enabled
    return if current_user&.admin? || Settings.project.create_permission_enabled

    flash.alert = 'You are not authorized to create new projects.'
    redirect_to root_path
  end

  #  Project permssions checking
  def authorize_admin_project
    return if current_user&.can_admin_project?(@project)

    raise(NotAuthorizedError, 'You are not authorized to perform administrator actions on this project')
  end

  def authorize_review_project
    return if current_user&.can_review_project?(@project)

    raise(NotAuthorizedError, 'You are not authorized to perform reviewer actions on this project')
  end

  def authorize_author_project
    return if current_user&.can_author_project?(@project)

    raise(NotAuthorizedError, 'You are not authorized to perform author actions on this project')
  end

  def authorize_viewer_project
    return if current_user&.can_view_project?(@project)

    raise(NotAuthorizedError, 'You are not authorized to perform viewer actions on this project')
  end

  #  Component permissions checking
  def authorize_admin_component
    return if current_user&.can_admin_component?(@component)

    raise(NotAuthorizedError, 'You are not authorized to perform administrator actions on this component')
  end

  def authorize_review_component
    return if current_user&.can_review_component?(@component)

    raise(NotAuthorizedError, 'You are not authorized to perform reviewer actions on this component')
  end

  def authorize_author_component
    return if current_user&.can_author_component?(@component)

    raise(NotAuthorizedError, 'You are not authorized to perform author actions on this component')
  end

  def authorize_viewer_component
    return if current_user&.can_view_component?(@component)

    raise(NotAuthorizedError, 'You are not authorized to perform viewer actions on this component')
  end

  def send_slack_notification(notification_type, object)
    channel = find_slack_channel(object)
    send_notification(channel, slack_notification_params(notification_type, object)) if channel.present?
  end

  def slack_notification_params(notification_type, object)
    notification_type_prefix = notification_type.to_s.match(/^(assign|create|update|upload|rename|remove)/)[1]
    icon, header = get_slack_headers_icons(notification_type, notification_type_prefix)
    fields = get_slack_notification_fields(object, notification_type, notification_type_prefix)
    {
      icon: icon,
      header: header,
      fields: fields
    }
  end

  def send_smtp_notification(mailer, action, *args)
    mailer.membership_action(action, *args).deliver_now if membership_action?(action)
    mailer.review_action(action, *args).deliver_now if review_action?(action)
  end

  private

  # Determine the slack channel or user id to which the slack notification should be sent.
  def find_slack_channel(object)
    return object.user.slack_user_id if object.is_a?(Membership) && object.user.slack_user_id.present?
    return object.slack_user_id if object.is_a?(User) && object.slack_user_id.present?

    if object.is_a?(Component) || object.is_a?(Project)
      return object.metadata['Slack Channel ID'] if object.metadata&.[]('Slack Channel ID').present?
      if object.is_a?(Component) && object.project.metadata&.[]('Slack Channel ID').present?
        return object.project.metadata['Slack Channel ID']
      end
    end

    Settings.slack.channel_id
  end

  def membership_action?(action)
    %w[welcome_user update_membership remove_membership].include?(action)
  end

  def review_action?(action)
    %w[request_review approve revoke_review_request request_changes].include?(action)
  end

  def helpful_errors(exception)
    # Based on the accepted response type, either send a JSON response with the
    # alert message, or redirect to home and display the alert.
    message = if current_user&.admin?
                exception.message
              else
                'Please contact an administrator if you believe this message is in error'
              end
    respond_to do |format|
      format.html do
        flash.alert = message
        redirect_back(fallback_location: root_path)
      end
      format.json do
        render json: {
          toast: {
            title: 'An error occurred processing your request.',
            message: message,
            variant: 'danger'
          }
        }, status: :internal_server_error
      end
    end
  end

  def not_authorized(exception)
    # Based on the accepted response type, either send a JSON response with the
    # alert message, or redirect to home and display the alert.
    respond_to do |format|
      format.html do
        flash.alert = exception.message
        redirect_back(fallback_location: root_path)
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
  end
end
