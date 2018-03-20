class SrgControl < ApplicationRecord
  belongs_to :srg, :inverse_of => :srg_controls
end
