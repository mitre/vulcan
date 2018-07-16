class ProjectControlHistoriesController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  def add_history
    project_control_history = ProjectControlHistory.create(project_control_histories_params)
    project_control_history.control_change_status = ControlChangeStatus.create({status: 'open'}) if project_control_history.history_type == 'change'
    ProjectControl.find(project_control_histories_params['project_control_id']).update_attribute(:status, 'Needs Changes') if project_control_history.history_type == 'change'
    return "Success"
  end
  
  private 
  # Never trust parameters from the scary internet, only allow the white list through.
  def project_control_histories_params
    params.require('project_control_histories').permit(:project_control_id, :project_control_attr, :text, :history_type, :is_reply_to, :user_id)
  end
end
