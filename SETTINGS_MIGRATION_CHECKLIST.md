# Settings to Setting Migration Checklist

This document tracks the migration from `Settings.*` (compatibility layer) to `Setting.*` (direct rails-settings-cached model).

## Migration Status: ✅ COMPLETE

All 50 occurrences across 22 files have been successfully migrated.

## Deployment Resources Created

For users upgrading to this version:

1. **Upgrade Guide**: `UPGRADE_GUIDE_SETTINGS.md` - General upgrade instructions
2. **Kubernetes Guide**: `docs/KUBERNETES_SETTINGS_MIGRATION.md` - K8s-specific migration
3. **Docker Compose Example**: `docker-compose.yml.example` - Container deployment template
4. **Environment Template**: `.env.example` - Required environment variables
5. **Preflight Check**: `bin/preflight-check` - Configuration validation tool
6. **Docker Entrypoint**: `docker-entrypoint.sh` - Automated container setup
7. **Optional Migration**: `db/migrate/20250612999999_migrate_yaml_settings_to_database.rb` - Import old YAML settings

## Migration Mapping Reference

### Naming Convention Changes
- `Settings.local_login.enabled` → `Setting.local_login_enabled`
- `Settings.oidc.args['key']` → `Setting.oidc_args['key']`
- `Settings.smtp.settings.transform_keys` → `Setting.smtp_settings.transform_keys`
- `Settings['welcome_text']` → `Setting.welcome_text`

### For nested hash access:
- `Settings.oidc.args.client_options.identifier` → `Setting.oidc_args.dig('client_options', 'identifier')`

## Files to Migrate

### Controllers (8 files, 27 occurrences)

- [ ] **app/controllers/sessions_controller.rb** (4 occurrences)
  - [ ] Line 13: `Settings.oidc.enabled`
  - [ ] Line 44: `Settings.app_url`
  - [ ] Line 53: `Settings.oidc.args.client_options.identifier`
  - [ ] Line 65: `Settings.oidc.args['issuer']`

- [ ] **app/controllers/users/registrations_controller.rb** (1 occurrence)
  - [ ] Line 10: `Settings.local_login.enabled`

- [ ] **app/controllers/application_controller.rb** (2 occurrences)
  - [ ] Line 37: `Settings.project.create_permission_enabled`
  - [ ] Line 138: `Settings.slack.channel_id`

- [ ] **app/controllers/security_requirements_guides_controller.rb** (2 occurrences)
  - [ ] Line 24: `Settings.slack.enabled`
  - [ ] Line 41: `Settings.slack.enabled`

- [ ] **app/controllers/users_controller.rb** (1 occurrence)
  - [ ] Line 22: `Settings.slack.enabled`

- [ ] **app/controllers/memberships_controller.rb** (4 occurrences)
  - [ ] Line 32: `Settings.smtp.enabled`
  - [ ] Line 49: `Settings.smtp.enabled`
  - [ ] Line 65: `Settings.smtp.enabled`
  - [ ] Line 106: `Settings.slack.enabled`

- [ ] **app/controllers/reviews_controller.rb** (2 occurrences)
  - [ ] Line 16: `Settings.smtp.enabled`
  - [ ] Line 27: `Settings.slack.enabled`

- [ ] **app/controllers/project_access_requests_controller.rb** (2 occurrences)
  - [ ] Line 13: `Settings.smtp.enabled`
  - [ ] Line 34: `Settings.smtp.enabled`

- [ ] **app/controllers/components_controller.rb** (2 occurrences)
  - [ ] Line 83: `Settings.slack.enabled`
  - [ ] Line 115: `Settings.slack.enabled`

- [ ] **app/controllers/projects_controller.rb** (3 occurrences)
  - [ ] Line 78: `Settings.slack.enabled`
  - [ ] Line 92: `Settings.slack.enabled`
  - [ ] Line 111: `Settings.slack.enabled`

- [ ] **app/controllers/concerns/oidc_discovery_helper.rb** (2 occurrences)
  - [ ] Line 315: `Settings.oidc.discovery`
  - [ ] Line 317: `Settings.oidc.args.issuer`

### Helpers (3 files, 7 occurrences)

- [ ] **app/helpers/sessions_helper.rb** (5 occurrences)
  - [ ] Line 20: `Settings.local_login.enabled`
  - [ ] Line 28: `Settings.oidc.enabled`
  - [ ] Line 32: `Settings.oidc.title`
  - [ ] Line 36: `Settings.local_login.enabled`
  - [ ] Line 40: `Settings.user_registration.enabled`

- [ ] **app/helpers/application_helper.rb** (1 occurrence)
  - [ ] Line 18: `Settings.project.create_permission_enabled`

- [ ] **app/helpers/slack_notifications_helper.rb** (1 occurrence)
  - [ ] Line 9: `Settings.slack.api_token`

### Views (2 files, 2 occurrences)

- [ ] **app/views/devise/sessions/new.html.haml** (1 occurrence)
  - [ ] Line 24: `Settings.ldap.servers.values.first['title']`

- [ ] **app/views/devise/shared/_what_is_vulcan.html.haml** (1 occurrence)
  - [ ] Line 4: `Settings['welcome_text']`

### Models (1 file, 1 occurrence)

- [ ] **app/models/user.rb** (1 occurrence)
  - [ ] Line 18: `Settings.local_login.email_confirmation`

### Mailers (2 files, 2 occurrences)

- [ ] **app/mailers/application_mailer.rb** (1 occurrence)
  - [ ] Line 6: `Settings.contact_email`

- [ ] **app/mailers/user_mailer.rb** (1 occurrence)
  - [ ] Line 7: `Settings.smtp.settings.user_name`

### Initializers (4 files, 16 occurrences)

- [ ] **config/initializers/devise.rb** (8 occurrences)
  - [ ] Line 287: `Settings.ldap.enabled`
  - [ ] Line 287: `Settings.ldap.servers.present?`
  - [ ] Line 291: `Settings.ldap.servers.values.first`
  - [ ] Line 295: `Settings.providers.present?`
  - [ ] Line 296: `Settings.providers.each`
  - [ ] Line 305: `Settings.oidc.enabled`
  - [ ] Line 305: `Settings.oidc.args.present?`
  - [ ] Line 306: `Settings.oidc.strategy.to_sym`
  - [ ] Line 306: `Settings.oidc.args`
  - [ ] Line 314: `Settings.local_login.session_timeout.minutes`

- [ ] **config/initializers/slack.rb** (3 occurrences)
  - [ ] Line 6: `Settings.slack.enabled`
  - [ ] Line 6: `Settings.slack.api_token.present?`
  - [ ] Line 8: `Settings.slack.api_token`

- [ ] **config/initializers/smtp_settings.rb** (5 occurrences)
  - [ ] Line 9: `Settings.smtp.enabled`
  - [ ] Line 9: `Settings.smtp.settings.present?`
  - [ ] Line 13: `Settings.app_url.present?`
  - [ ] Line 14: `Settings.app_url`
  - [ ] Line 17: `Settings.smtp.settings.transform_keys`

- [ ] **config/initializers/oidc_startup_validation.rb** (3 occurrences)
  - [ ] Line 13: `Settings.oidc&.enabled`
  - [ ] Line 14: `Settings.oidc.discovery`
  - [ ] Line 17: `Settings.oidc.args&.dig('issuer')`

## Total: 50 occurrences across 22 files

## Migration Steps

1. Update each file systematically
2. Run tests after each file or group of related files
3. Pay special attention to:
   - Hash access that needs `.dig()`
   - Nil checks that might need updating
   - Method chaining on Settings objects
4. Remove the Settings compatibility layer (`app/models/settings.rb`) once complete
5. Remove any remaining `config/settings.rb` references