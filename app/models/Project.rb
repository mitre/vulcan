class Project < ApplicationRecord
  before_destroy :destroy_project_controls
  
  has_many  :project_controls
  serialize :srg_ids
  accepts_nested_attributes_for :project_controls
  
  private

  def destroy_project_controls
    self.project_controls.destroy_all   
  end
end
