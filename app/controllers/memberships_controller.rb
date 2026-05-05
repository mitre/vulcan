# frozen_string_literal: true

##
# Controller for managing members of a specific project.
#
class MembershipsController < ApplicationController
  before_action :set_membership, only: %i[update destroy]
  before_action :authorize_admin_membership, only: %i[update destroy]
  before_action :authorize_membership_create, only: %i[create]

  def create
    filtered_params = membership_create_params.except(:access_request_id)
    membership = Membership.new(filtered_params)
    if membership.save
      delete_access_request(membership_create_params[:access_request_id]) if membership_create_params[:access_request_id].present?
      flash.notice = 'Successfully created membership.'
      notify_membership_change(membership, smtp_action: 'welcome_user', inapp_verb: 'create')

      respond_to do |format|
        format.html { redirect_to membership.membership }
        format.json do
          render_toast(title: 'Membership created.',
                       message: 'Successfully created membership.',
                       variant: 'success', status: :ok)
        end
      end
    else
      respond_to do |format|
        format.html do
          flash.alert = "Unable to create membership. #{membership.errors.full_messages}"
          redirect_back(fallback_location: root_path)
        end
        format.json do
          render json: {
            toast: {
              title: 'Could not create membership.',
              message: membership.errors.full_messages,
              variant: 'danger'
            }
          }, status: :unprocessable_entity
        end
      end
    end
  end

  def update
    if @membership.update(membership_update_params)
      notify_membership_change(@membership, smtp_action: 'update_membership', inapp_verb: 'update')

      respond_to do |format|
        format.html do
          flash.notice = 'Successfully updated membership.'
          redirect_to @membership.membership
        end
        format.json do
          render_toast(title: 'Membership updated.',
                       message: 'Successfully updated membership.',
                       variant: 'success', status: :ok)
        end
      end
    else
      respond_to do |format|
        format.html do
          flash.alert = "Unable to update membership. #{@membership.errors.full_messages}"
          redirect_to @membership.membership
        end
        format.json do
          render json: {
            toast: {
              title: 'Could not update membership.',
              message: @membership.errors.full_messages,
              variant: 'danger'
            }
          }, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    if @membership.destroy
      notify_membership_change(@membership, smtp_action: 'remove_membership', inapp_verb: 'remove')

      respond_to do |format|
        format.html do
          flash.notice = 'Successfully removed membership.'
          redirect_to @membership.membership
        end
        format.json do
          render_toast(title: 'Membership removed.',
                       message: 'Successfully removed membership.',
                       variant: 'success', status: :ok)
        end
      end
    else
      respond_to do |format|
        format.html do
          flash.alert = "Unable to remove membership. #{@membership.errors.full_messages}"
          redirect_to @membership.membership
        end
        format.json do
          render json: {
            toast: {
              title: 'Could not remove membership.',
              message: @membership.errors.full_messages,
              variant: 'danger'
            }
          }, status: :unprocessable_entity
        end
      end
    end
  end

  private

  # Single dispatch point for SMTP + in-app membership notifications.
  # Wraps each side-effect call in safely_notify so a notification failure
  # cannot turn a successful state-change action into a 500.
  def notify_membership_change(membership, smtp_action:, inapp_verb:)
    if Settings.smtp.enabled
      safely_notify("#{inapp_verb}_membership_smtp") do
        send_smtp_notification(UserMailer, smtp_action, current_user, membership)
      end
    end

    inapp_event = :"#{inapp_verb}_#{membership.membership_type.downcase}_membership"
    safely_notify("#{inapp_verb}_membership_inapp") do
      send_membership_notification(inapp_event, membership)
    end
  end

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

  def authorize_membership_create
    project_or_component = if membership_create_params[:membership_type] == 'Project'
                             Project.find_by(id: membership_create_params[:membership_id])
                           else
                             Component.find_by(id: membership_create_params[:membership_id])
                           end

    return if current_user.admin || current_user.effective_permissions(project_or_component) == 'admin'

    raise(
      NotAuthorizedError,
      "You are not authorized to manage permissions on this #{membership_create_params[:membership_type]}"
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
