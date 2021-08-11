# frozen_string_literal: true

##
# Controller for managing members of a specific project.
#
class ProjectsController < ApplicationController
  before_action :set_project, only: %i[destroy]
  before_action :authorize_admin_project, only: %i[destroy]
  before_action :authorize_review_project, only: %i[index]

  def index
    @projects = current_user.available_projects.alphabetical
  end

  def destroy
    if @project.destroy
      flash.notice = 'Successfully removed project.'
    else
      flash.alert = "Unable to remove project. #{@project.errors.full_messages}"
    end
    redirect_to action: 'index'
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end
end
