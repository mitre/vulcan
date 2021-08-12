# frozen_string_literal: true

##
# Controller for project rules.
#
class RulesController < ApplicationController
  before_action :set_rule, only: %i[show]
  before_action :set_project, only: %i[index]
  before_action :authorize_review_project

  def index
    @rules = @project.rules
  end

  def show
    render json: @rule
  end

  private

  def set_rule
    @rule = Rule.find(params[:id])
  end

  def set_project
    @project = if @rule
                 @rule.project
               else
                 Project.find(params[:project_id])
               end
  end
end
