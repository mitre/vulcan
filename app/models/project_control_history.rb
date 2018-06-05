class ProjectControlHistory < ApplicationRecord
  belongs_to :project_control, :inverse_of => :project_control_historys
  belongs_to :user, :inverse_of => :project_control_histories
end
