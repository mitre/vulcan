class DodAgency < ApplicationRecord
  belongs_to :project, :inverse_of => :dod_agency
  
  attr_encrypted :dod_name, key: Rails.application.secrets.db
  attr_encrypted :phone_number, key: Rails.application.secrets.db
  attr_encrypted :email, key: Rails.application.secrets.db
  attr_encrypted :organization, key: Rails.application.secrets.db
end
