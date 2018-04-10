class Cci < ApplicationRecord
  has_and_belongs_to_many :nist_controls
end
