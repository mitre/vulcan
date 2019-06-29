class DashboardController < ApplicationController
  def index
  end

  def new_session
    @db_user = DbUser.new
    @ldap_user = LdapUser.new
  end
end
