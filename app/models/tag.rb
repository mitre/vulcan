class Tag < ApplicationRecord
  field :name, type: String
  serialize :value
  belongs_to :control, :inverse_of => :tags
end
