class SponsorAgency < ApplicationRecord
  resourcify
  has_and_belongs_to_many :user
  
  attr_encrypted :sponsor_name, key: Rails.application.secrets.db
  attr_encrypted :phone_number, key: Rails.application.secrets.db
  attr_encrypted :email, key: Rails.application.secrets.db
  attr_encrypted :organization, key: Rails.application.secrets.db
end
