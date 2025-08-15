# frozen_string_literal: true

##
# Controller for managing members of a specific project.
#
class MembershipsController < ApplicationController
  before_action :set_membership, only: %i[update destroy]
  before_action :authorize_admin_membership, only: %i[update destroy]

  def create
    # Ensure the current_user has permissions on the Project or component
    project_or_component = if membership_create_params[:membership_type] == 'Project'
                             Project.find_by(id: membership_create_params[:membership_id])
                           else
                             Component.find_by(id: membership_create_params[:membership_id])
                           end

    unless current_user.admin || current_user.effective_permissions(project_or_component) == 'admin'
      raise(
        NotAuthorizedError,
        "You are not authorized to manage permissions on this #{membership_create_params[:membership_type]}"
      )
    end

    filtered_params = membership_create_params.except(:access_request_id)
    membership = Membership.new(filtered_params)
    if membership.save
      delete_access_request(membership_create_params[:access_request_id]) if membership_create_params[:access_request_id].present?
      flash.notice = 'Successfully created membership.'
      send_smtp_notification(UserMailer, 'welcome_user', current_user, membership) if Settings.smtp.enabled
      case membership.membership_type
      when 'Project'
        send_membership_notification(:create_project_membership, membership)
      when 'Component'
        send_membership_notification(:create_component_membership, membership)
      end
      redirect_to membership.membership
    else
      flash.alert = "Unable to create membership. #{membership.errors.full_messages}"
      redirect_back(fallback_location: root_path)
    end
  end

  def update
    if @membership.update(membership_update_params)
      flash.notice = 'Successfully updated membership.'
      send_smtp_notification(UserMailer, 'update_membership', current_user, @membership) if Settings.smtp.enabled
      case @membership.membership_type
      when 'Project'
        send_membership_notification(:update_project_membership, @membership)
      when 'Component'
        send_membership_notification(:update_component_membership, @membership)
      end
    else
      flash.alert = "Unable to updated membership. #{@membership.errors.full_messages}"
    end
    redirect_to @membership.membership
  end

  def destroy
    if @membership.destroy
      flash.notice = 'Successfully removed membership.'
      send_smtp_notification(UserMailer, 'remove_membership', current_user, @membership) if Settings.smtp.enabled
      case @membership.membership_type
      when 'Project'
        send_membership_notification(:remove_project_membership, @membership)
      when 'Component'
        send_membership_notification(:remove_component_membership, @membership)
      end
    else
      flash.alert = "Unable to remove membership. #{@membership.errors.full_messages}"
    end
    redirect_to @membership.membership
  end

  private

  def set_membership
    @membership = Membership.find(params[:id])
  end

  # This isn't in the application controller because it is specific to the membership controller
  def authorize_admin_membership
    effective_permissions = current_user.effective_permissions(@membership.membership)

    # Break early if the user is an admin
    return if effective_permissions == 'admin'

    raise(
      NotAuthorizedError,
      "You are not authorized to manage permissions on this #{@membership.membership_type}"
    )
  end

  def membership_create_params
    params.expect(membership: %i[user_id role membership_id membership_type access_request_id])
  end

  def membership_update_params
    params.expect(membership: [:role])
  end

  def send_membership_notification(notification_type, membership)
    return unless Settings.slack.enabled

    send_slack_notification(notification_type, membership)
  end

  def delete_access_request(access_request_id)
    access_request = ProjectAccessRequest.find_by(id: access_request_id)
    access_request&.destroy
  end
end
