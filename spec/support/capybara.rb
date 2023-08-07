# frozen_string_literal: true

Capybara.register_driver :chrome do |app|
  # TODO: setting the required version is a temp fix for the new chrome update.
  Webdrivers::Chromedriver.required_version = '114.0.5735.90'
  options = ::Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless') if ENV['CI']

  client = Selenium::WebDriver::Remote::Http::Default.new
  client.read_timeout = 120

  Capybara::Selenium::Driver.new(app, browser: :chrome, http_client: client, capabilities: [options])
end

Capybara.default_driver = :chrome
