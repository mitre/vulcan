class ControlChangeStatus < ApplicationRecord
  resourcify
  belongs_to :project_control_history, :inverse_of => :control_change_status
end
