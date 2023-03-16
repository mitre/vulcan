# frozen_string_literal: true

##
# Controller for managing members of a specific project.
#
class MembershipsController < ApplicationController
  include SlackNotificationsHelper
  before_action :set_membership, only: %i[update destroy]
  before_action :authorize_admin_membership, only: %i[update destroy]

  def create
    # Ensure the current_user has permissions on the Project or component
    current_user_effective_role = if current_user.admin
                                    'admin'
                                  else
                                    Membership.where(
                                      membership_type: membership_create_params[:membership_type],
                                      membership_id: membership_create_params[:membership_id],
                                      user_id: current_user.id
                                    ).pick(:role)
                                  end
    unless current_user_effective_role == 'admin'
      raise(
        NotAuthorizedError,
        "You are not authorized to manage permissions on this #{membership_create_params[:membership_type]}"
      )
    end

    membership = Membership.new(membership_create_params)
    if membership.save
      flash.notice = 'Successfully created membership.'
      if Settings.slack.enabled && membership.membership_type == 'Project'
        send_notification(
          Settings.slack.channel_id, slack_notification_params(:create_project_membership, membership)
        )
      end
      if Settings.slack.enabled && membership.membership_type == 'Component'
        send_notification(
          Settings.slack.channel_id, slack_notification_params(:create_component_membership, membership)
        )
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
      if Settings.slack.enabled && @membership.membership_type == 'Project'
        send_notification(
          Settings.slack.channel_id,
          slack_notification_params(:update_project_membership, @membership)
        )
      end
      if Settings.slack.enabled && @membership.membership_type == 'Component'
        send_notification(
          Settings.slack.channel_id,
          slack_notification_params(:update_component_membership, @membership)
        )
      end
    else
      flash.alert = "Unable to updated membership. #{@membership.errors.full_messages}"
    end
    redirect_to @membership.membership
  end

  def destroy
    if @membership.destroy
      flash.notice = 'Successfully removed membership.'
      if Settings.slack.enabled && @membership.membership_type == 'Project'
        send_notification(
          Settings.slack.channel_id,
          slack_notification_params(:remove_project_membership, @membership)
        )
      end
      if Settings.slack.enabled && @membership.membership_type == 'Component'
        send_notification(
          Settings.slack.channel_id,
          slack_notification_params(:remove_component_membership, @membership)
        )
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
    params.require(:membership).permit(:user_id, :role, :membership_id, :membership_type)
  end

  def membership_update_params
    params.require(:membership).permit(:role)
  end

  def slack_notification_params(notification_type, membership)
    notification_type_prefix = notification_type.to_s.match(/^(create|update|remove)/)[1]
    membership_types = %i[create_project_membership update_project_membership remove_project_membership]
    fields = [
      GENERAL_NOTIFICATION_FIELDS[:generate_app_label],
      if membership_types.include?(notification_type)
        MEMBERSHIP_NOTIFICATION_FIELDS[:generate_project_label]
      else
        MEMBERSHIP_NOTIFICATION_FIELDS[:generate_component_label]
      end,
      MEMBERSHIP_NOTIFICATION_FIELDS[:generate_member_action_label],
      MEMBERSHIP_NOTIFICATION_FIELDS[:generate_role_action_label],
      MEMBERSHIP_NOTIFICATION_FIELDS[:generate_initiated_by_label]
    ]
    headers = {
      create_project_membership: 'New Members Added to the Project',
      update_project_membership: 'Membership Updated on the Project',
      remove_project_membership: 'Members Removed from the Project',
      create_component_membership: 'New Members Added to the Component',
      update_component_membership: 'Membership Updated on the Component',
      remove_component_membership: 'Members Removed from the Component'
    }
    header = headers[notification_type]
    {
      icon: case notification_type
            when :create_project_membership, :create_component_membership
              ':white_check_mark:'
            when :update_project_membership, :update_component_membership
              ':loudspeaker:'
            when :remove_project_membership, :remove_component_membership
              ':x:'
            end,
      header: header,
      fields: fields.map do |field|
        label, value = field.values_at(:label, :value)
        label_content = label.respond_to?(:call) ? label.call(notification_type_prefix) : label
        value_content = value.respond_to?(:call) ? value.call(membership, current_user) : value
        { label: label_content, value: value_content }
      end
    }
  end
end
