class ProjectControlHistory < ApplicationRecord
  belongs_to :project_control, :inverse_of => :project_control_historys
end
