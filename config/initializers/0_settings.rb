# frozen_string_literal: true

# We load our settings first so that we can access them
# in other initializers

require_relative '../settings'

Settings['ldap'] ||= Settingslogic.new({})
Settings.ldap['enabled'] = false if Settings.ldap['enabled'].nil?

Settings['local_login'] ||= Settingslogic.new({})
Settings.local_login['enabled'] = false if Settings.local_login['enabled'].nil?

Settings['smtp'] ||= Settingslogic.new({})
Settings.smtp['enabled'] = false if Settings.smtp['enabled'].nil?

Settings['providers'] ||= Settingslogic.new({})

Settings['contact_email'] = 'do_not_reply@vulcan' if Settings['contact_email'].blank?
