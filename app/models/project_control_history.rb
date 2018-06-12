class ProjectControlHistory < ApplicationRecord
  belongs_to :project_control, :inverse_of => :project_control_historys
  belongs_to :user, :inverse_of => :project_control_histories
  
  attr_encrypted :project_control_id, key: Rails.application.secrets.db
  attr_encrypted :project_control_attr, key: Rails.application.secrets.db
  attr_encrypted :comment, key: Rails.application.secrets.db
end