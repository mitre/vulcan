require 'ripper'
###
# TODO: FORM VALIDATION
###
class ProjectControl < ApplicationRecord
  resourcify
  # validates_with ControlValidator
  attribute :title
  attribute :description
  attribute :impact
  attribute :code
  attribute :control_id
  attribute :checktext
  attribute :fixtext
  attribute :justification
  attribute :applicability
  attribute :status
  
  belongs_to :project, :inverse_of => :project_controls
  has_many :tags
  has_many  :project_control_historys
  has_and_belongs_to_many :nist_controls
  
  has_many :children, class_name: "ProjectControl",
                      foreign_key: "parent_id"
                  
  belongs_to :parent, class_name: "ProjectControl",
                      foreign_key: "parent_id", 
                      optional: true
    
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