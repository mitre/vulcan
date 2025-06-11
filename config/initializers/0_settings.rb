# frozen_string_literal: true

# We load our settings first so that we can access them
# in other initializers

require_relative '../settings'

Settings['ldap'] ||= Settingslogic.new({})
Settings.ldap['enabled'] = false if Settings.ldap['enabled'].nil?

Settings['oidc'] ||= Settingslogic.new({})
Settings.oidc['enabled'] = false if Settings.oidc['enabled'].nil?
Settings.oidc['discovery'] = true if Settings.oidc['discovery'].nil?

Settings['local_login'] ||= Settingslogic.new({})
Settings.local_login['enabled'] = false if Settings.local_login['enabled'].nil?

Settings['user_registration'] ||= Settingslogic.new({})
Settings.user_registration['enabled'] = false if Settings.user_registration['enabled'].nil?

Settings['project'] ||= Settingslogic.new({})
Settings.project['create_permission_enabled'] = false if Settings.project['create_permission_enabled'].nil?

Settings['smtp'] ||= Settingslogic.new({})
Settings.smtp['enabled'] = false if Settings.smtp['enabled'].nil?

Settings['slack'] ||= Settingslogic.new({})
Settings.slack['enabled'] = false if Settings.slack['enabled'].nil?

Settings['providers'] ||= Settingslogic.new({})

Settings['contact_email'] = 'do_not_reply@vulcan' if Settings['contact_email'].blank?
