class ProjectHistoriesController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  def add_project_history
    puts params
    project_history = ProjectHistory.create(project_histories_params)
    project_history.project_change_status = ProjectChangeStatus.create({status: 'open'}) if project_history.history_type == 'change'
    return "Success"
  end
  
  private 
  # Never trust parameters from the scary internet, only allow the white list through.
  def project_histories_params
    params.require('project_histories').permit(:project_id, :project_attr, :text, :history_type, :is_reply_to, :user_id)
  end
end
