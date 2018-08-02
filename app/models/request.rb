class Request < ApplicationRecord
  resourcify
  belongs_to :user, :inverse_of => :requests
  
  attribute :status
  attribute :role

  attr_encrypted :status, key: Rails.application.secrets.db
  attr_encrypted :role, key: Rails.application.secrets.db
end
