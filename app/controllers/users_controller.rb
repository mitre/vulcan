# frozen_string_literal: true

##
# Controller for application users.
#
class UsersController < ApplicationController
  include SlackNotificationsHelper
  before_action :authorize_admin
  before_action :set_user, only: %i[update destroy]

  def index
    @users = User.alphabetical.select(:id, :name, :email, :provider, :admin)
    @histories = Audited.audit_class.includes(:auditable, :user)
                        .where(auditable_type: 'User')
                        .order(created_at: :desc)
                        .map(&:format)
  end

  def update
    if @user.update(user_update_params)
      flash.notice = 'Successfully updated user.'
      if Settings.slack.enabled
        if user_update_params['admin'] == 'true'
          send_notification(
            Settings.slack.channel_id,
            slack_notification_params(:add_vulcan_admin, @user)
          )
        else
          send_notification(
            Settings.slack.channel_id,
            slack_notification_params(:remove_vulcan_admin, @user)
          )
        end
      end
    else
      flash.alert = "Unable to updated user. #{@user.errors.full_messages}"
    end
    redirect_to action: 'index'
  end

  def destroy
    if @user.destroy
      flash.notice = 'Successfully removed user.'
    else
      flash.alert = "Unable to remove user. #{@user.errors.full_messages}"
    end
    redirect_to action: 'index'
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_update_params
    params.require(:user).permit(:admin)
  end

  def slack_notification_params(notification_type, user)
    notification_type_prefix = notification_type.to_s.match(/^(add|remove)/)[1]
    fields = [
      GENERAL_NOTIFICATION_FIELDS[:generate_app_label],
      USER_NOTIFICATION_FIELDS[:generate_admin_role_action_label],
      USER_NOTIFICATION_FIELDS[:generate_initiated_by_label]
    ]
    header = case notification_type
             when :add_vulcan_admin
               'Assigning Vulcan Admin'
             when :remove_vulcan_admin
               'Removing Vulcan Admin'
             end
    {
      icon: case notification_type
            when :add_vulcan_admin
              ':white_check_mark:'
            when :remove_vulcan_admin
              ':x:'
            end,
      header: header,
      fields: fields.map do |field|
        label, value = field.values_at(:label, :value)
        label_content = label.respond_to?(:call) ? label.call(notification_type_prefix) : label
        value_content = value.respond_to?(:call) ? value.call(user, current_user) : value
        { label: label_content, value: value_content }
      end
    }
  end
end
