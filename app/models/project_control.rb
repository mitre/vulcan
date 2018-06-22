require 'ripper'
###
# TODO: FORM VALIDATION
###
class ProjectControl < ApplicationRecord
  # validates_with ControlValidator
  belongs_to :project, :inverse_of => :project_controls
  has_many :tags
  has_many  :project_control_historys
  has_and_belongs_to_many :nist_controls
  
  attr_encrypted :title, key: Rails.application.secrets.db
  attr_encrypted :description, key: Rails.application.secrets.db
  attr_encrypted :impact, key: Rails.application.secrets.db
  attr_encrypted :code, key: Rails.application.secrets.db
  attr_encrypted :control_id, key: Rails.application.secrets.db
  attr_encrypted :checktext, key: Rails.application.secrets.db
  attr_encrypted :fixtext, key: Rails.application.secrets.db
  attr_encrypted :justification, key: Rails.application.secrets.db
  attr_encrypted :applicability, key: Rails.application.secrets.db
  attr_encrypted :status, key: Rails.application.secrets.db
end