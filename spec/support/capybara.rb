# frozen_string_literal: true

Capybara.register_driver :chrome do |app|
  options = ::Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless') if ENV['CI']

  client = Selenium::WebDriver::Remote::Http::Default.new
  client.read_timeout = 120

  Capybara::Selenium::Driver.new(app, browser: :chrome, http_client: client, options: options)
end

Capybara.default_driver = :chrome
