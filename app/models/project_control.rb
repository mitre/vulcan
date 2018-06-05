class ProjectControl < ApplicationRecord
  belongs_to :project, :inverse_of => :project_controls
  has_many :tags
  has_many  :project_control_historys
  has_and_belongs_to_many :nist_controls
end
