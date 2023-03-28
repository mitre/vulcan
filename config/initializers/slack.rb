# frozen_string_literal: true

# Vulcan Integration with a slack channel
if Settings.slack.enabled
  Slack.configure do |config|
    config.token = Settings.slack.api_token
  end
end
