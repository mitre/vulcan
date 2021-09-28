# frozen_string_literal: true

# Audited initializer
Rails.application.reloader.to_prepare do
  Audited.config do |config|
    config.audit_class = VulcanAudit
  end
end
