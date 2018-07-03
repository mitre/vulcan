class Vendor < ApplicationRecord
  resourcify
  has_and_belongs_to_many :users
  
  
  attr_encrypted :vendor_name, key: Rails.application.secrets.db
  attr_encrypted :point_of_contact, key: Rails.application.secrets.db
  attr_encrypted :poc_phone_number, key: Rails.application.secrets.db
  attr_encrypted :poc_email, key: Rails.application.secrets.db
end
