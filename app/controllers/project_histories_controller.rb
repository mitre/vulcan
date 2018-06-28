class ProjectHistoriesController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  def add_project_history
    puts params
    ProjectHistory.create(project_histories_params)
    return "Success"
  end
  
  private 
  # Never trust parameters from the scary internet, only allow the white list through.
  def project_histories_params
    params.require('project_histories').permit(:project_id, :project_attr, :comment, :is_reply_to, :user_id)
  end
end
