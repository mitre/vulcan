class Project < ApplicationRecord
  before_destroy :destroy_project_controls
  
  has_many  :project_controls
  has_and_belongs_to_many :srgs
  serialize :srg_ids
  accepts_nested_attributes_for :project_controls
  
  private

  def destroy_project_controls
    self.project_controls.destroy_all   
  end
end
