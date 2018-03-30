class Profile < ApplicationRecord
  before_destroy :destroy_controls
  
  has_many  :controls
  serialize :srg_ids
  accepts_nested_attributes_for :controls
  
  private

  def destroy_controls
    self.controls.destroy_all   
  end
end
