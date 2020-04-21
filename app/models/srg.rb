class Srg < ApplicationRecord
  resourcify
  before_destroy :destroy_srg_controls

  has_many :srg_controls

  def full_title
    "#{title} #{version} #{release}"
  end

  private

  def destroy_srg_controls
    srg_controls.destroy_all
  end
end
