class Srg < ApplicationRecord
  resourcify
  before_destroy :destroy_srg_controls
  
  has_many :srg_controls
  
  private

  def destroy_srg_controls
    self.srg_controls.destroy_all   
  end
end
