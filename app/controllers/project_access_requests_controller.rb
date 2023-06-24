# frozen_string_literal: true

##
# Controller for managing request to access a specific project.
#
class ProjectAccessRequestsController < ApplicationController
  def create
    @project = Project.find(params[:project_id])
    @access_request = ProjectAccessRequest.new(user: current_user, project: @project)

    if @access_request.save
      flash.notice = 'Your request for access has been sent.'
    else
      flash.alert = @access_request.errors.full_messages.to_sentence
    end
    redirect_to projects_path
  end

  def destroy
    @access_request = ProjectAccessRequest.find(params[:id])
    if @access_request.destroy
      if params[:action] == 'reject' && Settings.smtp.enabled
        send_smtp_notification(UserMailer, 'reject_access', @access_request.user)
      end
      flash.notice = 'Your request for access has been cancelled.'
    else
      flash.alert = @access_request.errors.full_messages.to_sentence
    end

    redirect_back(fallback_location: projects_path)
  end
end
