class LdapUser < User
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :ldap_authenticatable, :rememberable, :trackable, :validatable

  def ldap_before_save
    self.email = Devise::LDAP::Adapter.get_ldap_param(email, 'mail').first
  end

  def will_save_change_to_email?
    false
  end
end
