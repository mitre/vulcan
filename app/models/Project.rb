class Project < ApplicationRecord
  before_destroy :destroy_project_controls
  
  has_many  :project_controls
  has_and_belongs_to_many :srgs
  serialize :srg_ids
  accepts_nested_attributes_for :project_controls
  
  # def to_csv
  #   attributes = %w{name title maintainer copyright copyright_email license summary version srg_ids}
  # 
  #   CSV.generate(headers: true) do |csv|
  #     csv << attributes
  # 
  #     csv << attributes.map{ |attr| self.send(attr) }
  #   end
  # end
  
  private

  def destroy_project_controls
    self.project_controls.destroy_all   
  end
end
