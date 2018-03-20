class Profile < ApplicationRecord
  has_many :controls
  accepts_nested_attributes_for :controls
end
