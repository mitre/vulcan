###
# TODO: FORM VALIDATION
###
class ProjectControlHistory < ApplicationRecord
  resourcify
  belongs_to :project_control, :inverse_of => :project_control_historys
  belongs_to :user, :inverse_of => :project_control_histories
  has_one :control_change_status
end