# frozen_string_literal: true

# Vulcan Integration with a slack channel
# Defer Settings access until after Rails initialization to avoid deprecation warnings
Rails.application.config.after_initialize do
  if Settings.slack.enabled && Settings.slack.api_token.present?
    Slack.configure do |config|
      config.token = Settings.slack.api_token
    end
  end
end
