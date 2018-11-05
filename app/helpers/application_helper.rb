module ApplicationHelper
  def grouped_orgs
    {
      'Vendor' => Vendor.all.collect { |vendor| [vendor.vendor_name, vendor.id.to_s + '-vendor'] },
        'Sponsor Agency' => SponsorAgency.all.collect { |sponsor| [sponsor.sponsor_name, sponsor.id.to_s + '-sponsor'] }
    }
  end
  def destroy_user_session_path(user)
    if user.class == DbUser
      destroy_db_user_session_path
    elsif user.class == LdapUser
      destroy_ldap_user_session_path
    else
      Rails.logger.debug("It's broken")
    #when DbUser then destroy_db_user_session_path
    #when LdapUser then destroy_ldap_user_session_path
    end
  end
end
