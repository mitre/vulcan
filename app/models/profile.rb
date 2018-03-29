class Profile < ApplicationRecord
  has_many  :controls
  serialize :srg_ids
  accepts_nested_attributes_for :controls
end
