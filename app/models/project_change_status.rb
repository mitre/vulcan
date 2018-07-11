class ProjectChangeStatus < ApplicationRecord
  resourcify
  belongs_to :project_history, :inverse_of => :project_change_status
end
