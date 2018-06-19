class HostConfig < ApplicationRecord
  belongs_to :user, :inverse_of => :host_configs, required: false
  # attribute :host
  # attribute :user
  # attribute :password
  # attribute :transport_method
  # attribute :port
  # attribute :aws_region
  # attribute :aws_profile
  
  attr_encrypted :host, key: Rails.application.secrets.db
  attr_encrypted :user, key: Rails.application.secrets.db
  attr_encrypted :password, key: Rails.application.secrets.db
  attr_encrypted :transport_method, key: Rails.application.secrets.db
  attr_encrypted :port, key: Rails.application.secrets.db
  attr_encrypted :aws_region, key: Rails.application.secrets.db
  attr_encrypted :aws_access_key, key: Rails.application.secrets.db
  attr_encrypted :aws_secret_key, key: Rails.application.secrets.db
end
