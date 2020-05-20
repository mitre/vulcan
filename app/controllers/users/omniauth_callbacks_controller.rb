# frozen_string_literal: true

class Users
  # When Omniauth callbacks come back successful, this is the controller
  # that is hit. Currently we don't have any provider-specific code, since
  # both LDAP and Github return data in a similar enough manner.
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def all
      user = User.from_omniauth(request.env['omniauth.auth'])
      if user.persisted?
        flash.notice = 'Signed in!'
      else
        user.save
        flash.notice = 'Created account!'
      end
      sign_in_and_redirect(user) && return
    end

    alias ldap all
    alias github all
  end
end
