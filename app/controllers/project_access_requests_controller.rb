# frozen_string_literal: true

##
# Controller for managing request to access a specific project.
#
class ProjectAccessRequestsController < ApplicationController
  def create
    @project = Project.find(params[:project_id])
    @access_request = ProjectAccessRequest.new(user: current_user, project: @project)

    respond_to do |format|
      if @access_request.save
        send_smtp_notification(UserMailer, 'request_access', @access_request.user, @access_request.project) if Settings.smtp.enabled
        format.json { render json: { message: 'Your request for access has been sent.' }, status: :created }
        format.html do
          flash.notice = 'Your request for access has been sent.'
          redirect_to root_path
        end
      else
        format.json { render json: { error: @access_request.errors.full_messages.to_sentence }, status: :unprocessable_entity }
        format.html do
          flash.alert = @access_request.errors.full_messages.to_sentence
          redirect_to root_path
        end
      end
    end
  end

  def destroy
    @access_request = ProjectAccessRequest.find(params[:id])

    # Authorization check: Users can only delete their own requests or must be project admin
    unless @access_request.user == current_user || current_user.can_admin_project?(@access_request.project)
      respond_to do |format|
        format.json { render json: { error: 'You are not authorized to delete this access request.' }, status: :forbidden }
        format.html do
          flash.alert = 'You are not authorized to delete this access request.'
          redirect_back(fallback_location: root_path)
        end
      end
      return
    end

    respond_to do |format|
      if @access_request.destroy
        if current_user.can_admin_project?(@access_request.project)
          send_smtp_notification(UserMailer, 'reject_access', @access_request.user, @access_request.project) if Settings.smtp.enabled
          message = "Successfully denied #{@access_request.user.name}'s request to access project."
        else
          message = "Your request to access #{@access_request.project.name} has been cancelled."
        end
        format.json { render json: { message: message }, status: :ok }
        format.html do
          flash.notice = message
          redirect_back(fallback_location: root_path)
        end
      else
        format.json { render json: { error: @access_request.errors.full_messages.to_sentence }, status: :unprocessable_entity }
        format.html do
          flash.alert = @access_request.errors.full_messages.to_sentence
          redirect_back(fallback_location: root_path)
        end
      end
    end
  end
end
