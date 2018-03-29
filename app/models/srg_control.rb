class SrgControl < ApplicationRecord
  belongs_to :srg
  has_many :nist_families
end
