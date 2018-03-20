class Control < ApplicationRecord
  belongs_to :profile, :inverse_of => :controls
  has_many :tags
end
