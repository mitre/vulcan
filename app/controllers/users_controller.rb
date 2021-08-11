# frozen_string_literal: true

##
# Controller for managing members of a specific project.
#
class UsersController < ApplicationController
  before_action :set_user, only: %i[update destroy]
  before_action :authorize

  def index
    @users = User.alphabetical
  end

  def update
    if @user.update(user_update_params)
      flash.notice = 'Successfully updated user.'
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

  def authorize
    return if current_user.admin

    raise(NotAuthorizedError, 'You are not authorized to manage application users.')
  end

  def user_update_params
    params.require(:user).permit(:admin)
  end
end
