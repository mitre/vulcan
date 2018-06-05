class ProjectControlHistoriesController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  def add_history
    ProjectControlHistory.create(project_control_histories_params)
    return "Success"
  end
  
  private 
  # Never trust parameters from the scary internet, only allow the white list through.
  def project_control_histories_params
    params.require('project_control_histories').permit(:project_control_id, :project_control_attr, :comment, :is_reply_to, :user_id)
  end
end
