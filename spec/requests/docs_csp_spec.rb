# frozen_string_literal: true

require 'rails_helper'

##
# The documentation site ships two inline scripts, one of which applies the
# saved light/dark preference before first paint. The application's policy has
# no unsafe-inline, so without a nonce the browser blocks them and the site
# loads with the wrong appearance. These examples pin the nonce and, just as
# importantly, pin that the policy was not loosened to achieve it.
#
RSpec.describe 'Docs site content security policy' do
  before(:all) { DocsSiteHelpers.require_built_site! }

  before do
    Rails.application.reload_routes!
  end

  def inline_script_tags(body)
    body.scan(/<script(?![^>]*\ssrc=)[^>]*>/i)
  end

  # style-src legitimately carries unsafe-inline, so a whole-header assertion
  # would be testing the wrong directive.
  def script_src(response)
    response.headers['Content-Security-Policy'].split(';').map(&:strip).find { |d| d.start_with?('script-src') }
  end

  it 'gives every inline script the request nonce' do
    get '/docs'

    tags = inline_script_tags(response.body)
    expect(tags).not_to be_empty
    expect(tags).to all(match(/\snonce="[^"]+"/))
  end

  it 'uses the same nonce the policy header advertises' do
    get '/docs'

    body_nonce = response.body[/<script(?![^>]*\ssrc=)[^>]*\snonce="([^"]+)"/, 1]

    expect(response.headers['Content-Security-Policy']).to include("'nonce-#{body_nonce}'")
  end

  it 'issues a different nonce on each request' do
    get '/docs'
    first = response.body[/nonce="([^"]+)"/, 1]

    get '/docs'
    second = response.body[/nonce="([^"]+)"/, 1]

    expect(first).to be_present
    expect(second).not_to eq(first)
  end

  it 'leaves scripts that load from a file untouched' do
    get '/docs'

    module_tags = response.body.scan(/<script[^>]*\ssrc="[^"]*"[^>]*>/)

    expect(module_tags).not_to be_empty
    expect(module_tags.select { |tag| tag.include?('nonce=') }).to be_empty
  end

  it 'does not loosen the script policy to make the site work' do
    get '/docs'

    expect(script_src(response)).to start_with("script-src 'self'")
    expect(script_src(response)).not_to include("'unsafe-inline'")
  end

  it 'still applies the script policy to the rest of the application' do
    get '/users/sign_in'

    expect(script_src(response)).not_to include("'unsafe-inline'")
  end
end
