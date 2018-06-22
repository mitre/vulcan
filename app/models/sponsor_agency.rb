class SponsorAgency < ApplicationRecord
  belongs_to :project, :inverse_of => :sponsor_agency
  
  attr_encrypted :sponsor_name, key: Rails.application.secrets.db
  attr_encrypted :phone_number, key: Rails.application.secrets.db
  attr_encrypted :email, key: Rails.application.secrets.db
  attr_encrypted :organization, key: Rails.application.secrets.db
end
