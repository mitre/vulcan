class SponsorAgency < ApplicationRecord
  resourcify
  has_and_belongs_to_many :users
  
  attribute :sponsor_name
  attribute :phone_number
  attribute :email
  attribute :organization
  
  attr_encrypted :sponsor_name, key: Rails.application.secrets.db
  attr_encrypted :phone_number, key: Rails.application.secrets.db
  attr_encrypted :email, key: Rails.application.secrets.db
  attr_encrypted :organization, key: Rails.application.secrets.db
end
