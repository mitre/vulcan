# frozen_string_literal: true

##
# Controller for managing request to access a specific project.
#
class ProjectAccessRequestsController < ApplicationController
  before_action :authorize_logged_in, only: %i[create]
  before_action :set_and_authorize_access_request, only: %i[destroy]

  def create
    @project = Project.find(params.expect(:project_id))
    @access_request = ProjectAccessRequest.new(user: current_user, project: @project)

    if @access_request.save
      if Settings.smtp.enabled
        safely_notify('request_access') do
          send_smtp_notification(UserMailer, 'request_access', @access_request.user, @access_request.project)
        end
      end

      respond_to do |format|
        format.html do
          flash.notice = 'Your request for access has been sent.'
          redirect_to root_path
        end
        format.json do
          render_toast(title: 'Access request submitted.', message: ['Your request for access has been sent.'],
                       variant: 'success', status: :ok, id: @access_request.id)
        end
      end
    else
      respond_to do |format|
        format.html do
          flash.alert = @access_request.errors.full_messages.to_sentence
          redirect_to root_path
        end
        format.json do
          render_toast(title: 'Could not request access.', message: @access_request.errors.full_messages)
        end
      end
    end
  end

  def destroy
    if @access_request.destroy
      if current_user.can_admin_project?(@access_request.project)
        if Settings.smtp.enabled
          safely_notify('reject_access_request') do
            send_smtp_notification(UserMailer, 'reject_access', @access_request.user, @access_request.project)
          end
        end
        title = 'Access request denied.'
        message = "Successfully denied #{@access_request.user.name}'s request to access project."
      else
        title = 'Access request cancelled.'
        message = "Your request to access #{@access_request.project.name} has been cancelled."
      end

      respond_to do |format|
        format.html do
          flash.notice = message
          redirect_back_or_to(root_path)
        end
        # multi-key response (toast + id).
        format.json do
          render_toast(title: title, message: [message], variant: 'success', status: :ok, id: @access_request.id)
        end
      end
    else
      respond_to do |format|
        format.html do
          flash.alert = @access_request.errors.full_messages.to_sentence
          redirect_back_or_to(root_path)
        end
        format.json { render json: { error: @access_request.errors.full_messages.to_sentence }, status: :unprocessable_content }
      end
    end
  end

  private

  def set_and_authorize_access_request
    @access_request = ProjectAccessRequest.find(params.expect(:id))

    return if @access_request.user == current_user || current_user.can_admin_project?(@access_request.project)

    # Expose the project so a denial on a non-discoverable project is concealed
    # as a 404 rather than revealing the request exists.
    @project = @access_request.project
    raise(NotAuthorizedError, 'You are not authorized to delete this access request.')
  end
end
