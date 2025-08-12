# frozen_string_literal: true

# Audited initializer
# Use string class name to avoid Zeitwerk autoloading issues
# See: https://github.com/collectiveidea/audited/issues/608
Audited.config do |config|
  config.audit_class = 'VulcanAudit'
end
