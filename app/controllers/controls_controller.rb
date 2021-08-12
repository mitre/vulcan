# frozen_string_literal: true

##
# Controller for project rules/controls.
#
class ControlsController < ApplicationController
  before_action :set_project, only: %i[index]
  before_action :authorize_review_project

  def index
    @controls = @project.rules
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end
end
