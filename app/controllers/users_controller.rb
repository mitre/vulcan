# frozen_string_literal: true

##
# Controller for application users.
#
class UsersController < ApplicationController
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
      notification_type = @user.admin ? :assign_vulcan_admin : :remove_vulcan_admin
      send_slack_notification(notification_type, @user) if Settings.slack.enabled

      respond_to do |format|
        format.html do
          flash.notice = 'Successfully updated user.'
          redirect_to action: 'index'
        end
        format.json { render json: { toast: 'Successfully updated user' } }
      end
    else
      respond_to do |format|
        format.html do
          flash.alert = "Unable to update user. #{@user.errors.full_messages}"
          redirect_to action: 'index'
        end
        format.json do
          render json: {
            toast: {
              title: 'Could not update user.',
              message: @user.errors.full_messages,
              variant: 'danger'
            }
          }, status: :unprocessable_entity
        end
      end
    end
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
    params.expect(user: [:admin])
  end
end
