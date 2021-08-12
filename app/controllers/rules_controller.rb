# frozen_string_literal: true

##
# Controller for project rules.
#
class RulesController < ApplicationController
  before_action :set_project, only: %i[index]
  before_action :authorize_review_project

  def index
    @rules = @project.rules
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end
end
