# frozen_string_literal: true

# This is the base controller for the application. Things should only be
# placed here if they are shared between multiple controllers
class ApplicationController < ActionController::Base
  helper :all
  include SlackNotificationsHelper

  before_action :setup_navigation, :authenticate_user!
  before_action :check_access_request_notifications
  before_action :check_locked_user_notifications

  # AC-8: Determines if the current user must acknowledge consent.
  # Returns true when consent is enabled and the session has no valid acknowledgment.
  def consent_required?
    return false unless Settings.consent&.enabled

    acknowledged_at = session[:consent_acknowledged_at]
    return true if acknowledged_at.blank?

    ttl = Settings.consent.respond_to?(:ttl) ? Settings.consent.ttl : nil
    return false if ttl.blank? || ttl.to_s == '0'

    parsed = Time.zone.parse(acknowledged_at)
    return true unless parsed # nil from unparseable string → re-prompt

    parsed + parse_duration(ttl) < Time.current
  rescue ArgumentError
    true # corrupted timestamp → re-prompt
  end
  helper_method :consent_required?

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

  # NOTE: Anonymous rest args (*) is valid Ruby 3.2+ syntax for argument forwarding.
  # RuboCop Style/ArgumentsForwarding enforces this form. Not a syntax error.
  def send_slack_notification(notification_type, object, *)
    channels = find_slack_channel(object, notification_type)
    channels.each do |channel|
      send_notification(channel, slack_notification_params(notification_type, object, *))
    end
  end

  def slack_notification_params(notification_type, object, *)
    pattern = /^(
      approve|
      revoke|
      request_changes|
      request_review|
      assign|
      create|
      update|
      upload|
      rename|
      remove|
      change_visibility
    )/x

    notification_type_prefix = notification_type.to_s.match(pattern)[1]
    icon, header = get_slack_headers_icons(notification_type, notification_type_prefix)
    fields = get_slack_notification_fields(object, notification_type, notification_type_prefix, *)
    {
      icon: icon,
      header: header,
      fields: fields
    }
  end

  def send_smtp_notification(mailer, action, *)
    mailer.membership_action(action, *).deliver_now if membership_action?(action)
    mailer.review_action(action, *).deliver_now if review_action?(action)
    mailer.project_access_action(action, *).deliver_now if access_request_action?(action)
  end

  private

  # Parses duration strings like "1h", "30m", "24h", "3600" into seconds.
  def parse_duration(value)
    str = value.to_s.strip
    case str
    when /\A(\d+)h\z/i then ::Regexp.last_match(1).to_i.hours
    when /\A(\d+)m\z/i then ::Regexp.last_match(1).to_i.minutes
    when /\A(\d+)s?\z/ then ::Regexp.last_match(1).to_i.seconds
    else 0.seconds
    end
  end

  # Determine the slack channel(s) and user id to which the slack notification should be sent.
  def find_slack_channel(object, notification_type)
    channels = []
    # In all case except for review request, the general channel
    # (default configured with the Vulcan instance) will be notified
    channels << Settings.slack.channel_id unless object.is_a?(Rule)
    # Usecase: requesting a review, revoking review request, approving or requesting changes on a control
    case object
    when Rule
      # Getting the component or project slack channel
      comp = object.component
      channels << (comp.metadata&.dig('Slack Channel ID') || comp.project.metadata&.dig('Slack Channel ID'))
      # Getting the slack user id of the user who initially requested the review
      channels << latest_reviewer_slack_id(object) unless notification_type.to_s == 'request_review'
    when Membership
      # Usecase: updating project/component membership role
      channels << object.user.slack_user_id
    when User
      # Usecase: updating Vulcan role (admin/user)
      channels << object.slack_user_id
    when Project
      # Usecase: Project creation, removal, & renaming
      channels << object.metadata&.dig('Slack Channel ID')
    when Component
      # Usecase: Component creation and removal
      channels << (object.metadata&.dig('Slack Channel ID') || object.project.metadata&.dig('Slack Channel ID'))
    end

    channels.compact.uniq
  end

  def latest_reviewer_slack_id(rule)
    latest_review = Review.where(
      rule_id: Rule.find_by(rule_id: rule.rule_id.to_s, component_id: rule.component_id).id,
      action: 'request_review'
    ).order(updated_at: :desc).first
    latest_review&.user&.slack_user_id
  end

  def membership_action?(action)
    %w[welcome_user update_membership remove_membership].include?(action)
  end

  def review_action?(action)
    %w[request_review approve revoke_review_request request_changes].include?(action)
  end

  def access_request_action?(action)
    %w[request_access reject_access].include?(action)
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

  def check_access_request_notifications
    @access_requests = []
    return @access_requests unless user_signed_in?
    return @access_requests if request.format.json? # Skip for API calls — navbar not rendered

    # Single query: find all access requests for projects where current user is admin.
    # Replaces N+1 loop that called can_admin_project? + eager_load per project.
    admin_project_ids = if current_user.admin?
                          Project.pluck(:id)
                        else
                          Membership.where(user_id: current_user.id, role: 'admin',
                                           membership_type: 'Project')
                                    .pluck(:membership_id)
                        end

    return @access_requests if admin_project_ids.empty?

    @access_requests = ProjectAccessRequest.where(project_id: admin_project_ids)
                                           .eager_load(:user, :project)
                                           .map do |ar|
      {
        id: ar.id,
        user: UserBlueprint.render_as_hash(ar.user),
        project: { id: ar.project.id, name: ar.project.name }
      }
    end
  end

  def check_locked_user_notifications
    @locked_users = []
    return unless user_signed_in? && current_user.admin? && Settings.lockout&.enabled

    @locked_users = User.where.not(locked_at: nil)
                        .limit(100)
                        .select(:id, :name, :email)
                        .as_json(only: %i[id name email])
  end
end
