class SrgControl < ApplicationRecord
  has_and_belongs_to_many :nist_controls
  belongs_to :srg
end
