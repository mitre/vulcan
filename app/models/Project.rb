class Project < ApplicationRecord
  before_destroy :destroy_project_controls
  
  has_many  :project_controls
  has_and_belongs_to_many :srgs
  has_and_belongs_to_many :users
  serialize :srg_ids
  accepts_nested_attributes_for :project_controls
  
  attr_encrypted :name, key: Rails.application.secrets.db
  attr_encrypted :title, key: Rails.application.secrets.db
  attr_encrypted :maintainer, key: Rails.application.secrets.db
  attr_encrypted :copyright, key: Rails.application.secrets.db
  attr_encrypted :copyright_email, key: Rails.application.secrets.db
  attr_encrypted :license, key: Rails.application.secrets.db
  attr_encrypted :summary, key: Rails.application.secrets.db
  attr_encrypted :version, key: Rails.application.secrets.db

  
  # def to_csv
  #   attributes = %w{name title maintainer copyright copyright_email license summary version srg_ids}
  # 
  #   CSV.generate(headers: true) do |csv|
  #     csv << attributes
  # 
  #     csv << attributes.map{ |attr| self.send(attr) }
  #   end
  # end
  
  private
  
  # def encrypt_title
  #   self.title = CRYPT.encrypt_and_sign(self.title) # or crypt.encrypt_and_sign(self.consumer_key)
  #   # self.title = crypt.decrypt_and_verify(encrypted_data)  
  # end
  # 
  # def decrypt
  #   self.title = CRYPT.decrypt_and_verify(self.title)
  # end
  
  # def encryptor
  #   # key = ENV['KEY']  # We save the value of: ActiveSupport::KeyGenerator.new('password').generate_key(salt)
  #   # len   = ActiveSupport::MessageEncryptor.key_len
  #   # salt  = SecureRandom.random_bytes(len)
  #   # sub_key   = ActiveSupport::KeyGenerator.new(key).generate_key(salt, len)
  #   # ENV['key'] = sub_key
  #   # ActiveSupport::MessageEncryptor.new(key)
  # end

  def destroy_project_controls
    self.project_controls.destroy_all   
  end
end
