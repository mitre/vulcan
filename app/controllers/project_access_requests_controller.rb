# frozen_string_literal: true

##
# Controller for managing request to access a specific project.
#
class ProjectAccessRequestsController < ApplicationController
  before_action :authorize_logged_in, only: %i[create]
  before_action :set_and_authorize_access_request, only: %i[destroy]

  def create
    @project = Project.find(params[:project_id])
    @access_request = ProjectAccessRequest.new(user: current_user, project: @project)

    if @access_request.save
      flash.notice = 'Your request for access has been sent.'
      send_smtp_notification(UserMailer, 'request_access', @access_request.user, @access_request.project) if Settings.smtp.enabled
    else
      flash.alert = @access_request.errors.full_messages.to_sentence
    end
    redirect_to root_path
  end

  def destroy
    if @access_request.destroy
      if current_user.can_admin_project?(@access_request.project)
        send_smtp_notification(UserMailer, 'reject_access', @access_request.user, @access_request.project) if Settings.smtp.enabled
        toast = "Sucessfully denied #{@access_request.user.name}'s request to access project."
      else
        toast = "Your request to access #{@access_request.project.name} has been cancelled."
      end

      respond_to do |format|
        format.html do
          flash.notice = toast
          redirect_back(fallback_location: root_path)
        end
        format.json { render json: { toast: toast, id: @access_request.id } }
      end
    else
      respond_to do |format|
        format.html do
          flash.alert = @access_request.errors.full_messages.to_sentence
          redirect_back(fallback_location: root_path)
        end
        format.json { render json: { error: @access_request.errors.full_messages.to_sentence }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_and_authorize_access_request
    @access_request = ProjectAccessRequest.find(params[:id])

    return if @access_request.user == current_user || current_user.can_admin_project?(@access_request.project)

    raise(NotAuthorizedError, 'You are not authorized to delete this access request.')
  end
end
