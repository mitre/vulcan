###
# TODO: FORM VALIDATION
###
class HostConfig < ApplicationRecord
  resourcify
  belongs_to :user, :inverse_of => :host_configs, required: false
  
  attr_encrypted :host, key: Rails.application.secrets.db
  attr_encrypted :user, key: Rails.application.secrets.db
  attr_encrypted :password, key: Rails.application.secrets.db
  attr_encrypted :transport_method, key: Rails.application.secrets.db
  attr_encrypted :port, key: Rails.application.secrets.db
  attr_encrypted :aws_region, key: Rails.application.secrets.db
  attr_encrypted :aws_access_key, key: Rails.application.secrets.db
  attr_encrypted :aws_secret_key, key: Rails.application.secrets.db
end
