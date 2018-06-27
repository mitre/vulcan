class NistControl < ApplicationRecord
  resourcify
  has_and_belongs_to_many :ccis
  has_and_belongs_to_many :srg_controls
  has_and_belongs_to_many :project_controls
end
