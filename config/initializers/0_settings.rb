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
Settings.local_login['enabled'] = true if Settings.local_login['enabled'].nil?

Settings['user_registration'] ||= Settingslogic.new({})
Settings.user_registration['enabled'] = true if Settings.user_registration['enabled'].nil?

Settings['project'] ||= Settingslogic.new({})
Settings.project['create_permission_enabled'] = true if Settings.project['create_permission_enabled'].nil?

Settings['smtp'] ||= Settingslogic.new({})
Settings.smtp['enabled'] = false if Settings.smtp['enabled'].nil?

Settings['banner'] ||= Settingslogic.new({})
Settings.banner['enabled'] = false if Settings.banner['enabled'].nil?
Settings.banner['text'] = '' if Settings.banner['text'].nil?
Settings.banner['background_color'] = '#007a33' if Settings.banner['background_color'].blank?
Settings.banner['text_color'] = '#ffffff' if Settings.banner['text_color'].blank?

Settings['consent'] ||= Settingslogic.new({})
Settings.consent['enabled'] = false if Settings.consent['enabled'].nil?
Settings.consent['version'] = '1' if Settings.consent['version'].blank?
Settings.consent['title'] = 'Terms of Use' if Settings.consent['title'].blank?
Settings.consent['content'] = '' if Settings.consent['content'].nil?

Settings['lockout'] ||= Settingslogic.new({})
Settings.lockout['enabled'] = true if Settings.lockout['enabled'].nil?
Settings.lockout['maximum_attempts'] = 3 if Settings.lockout['maximum_attempts'].nil?
Settings.lockout['unlock_in_minutes'] = 15 if Settings.lockout['unlock_in_minutes'].nil?
Settings.lockout['unlock_strategy'] = 'both' if Settings.lockout['unlock_strategy'].blank?
Settings.lockout['last_attempt_warning'] = true if Settings.lockout['last_attempt_warning'].nil?

Settings['password'] ||= Settingslogic.new({})
Settings.password['min_length'] = 15 if Settings.password['min_length'].nil?
Settings.password['min_uppercase'] = 2 if Settings.password['min_uppercase'].nil?
Settings.password['min_lowercase'] = 2 if Settings.password['min_lowercase'].nil?
Settings.password['min_number'] = 2 if Settings.password['min_number'].nil?
Settings.password['min_special'] = 2 if Settings.password['min_special'].nil?

Settings['slack'] ||= Settingslogic.new({})
Settings.slack['enabled'] = false if Settings.slack['enabled'].nil?

Settings['providers'] ||= Settingslogic.new({})

Settings['contact_email'] = 'vulcan-support@example.com' if Settings['contact_email'].blank?
