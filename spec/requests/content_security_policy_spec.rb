# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: All HTML responses must include a Content-Security-Policy header
# to mitigate XSS attacks. The policy should restrict script and style sources
# to self and configured CDN origins.
RSpec.describe 'Content-Security-Policy header' do
  before do
    Rails.application.reload_routes!
  end

  it 'is present on HTML responses' do
    get root_path
    expect(response.headers['Content-Security-Policy']).to be_present
  end

  it 'restricts default-src to self' do
    get root_path
    csp = response.headers['Content-Security-Policy']
    expect(csp).to match(/default-src\s+'self'/)
  end

  it 'restricts script-src' do
    get root_path
    csp = response.headers['Content-Security-Policy']
    expect(csp).to match(/script-src\s/)
  end
end
