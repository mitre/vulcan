# frozen_string_literal: true

# Vulcan Integration with a slack channel
if Settings.slack.enabled && Settings.slack.api_token.present?
  Slack.configure do |config|
    config.token = Settings.slack.api_token
  end
end
