# frozen_string_literal: true

require 'rails_helper'

# The catch-all StandardError rescue must never swallow silently: the JSON
# body is a generic toast, so the log line is the ONLY place the root cause
# survives. A 500 without a logged class/message/backtrace is undebuggable.
RSpec.describe 'helpful_errors rescue', openapi: false do
  include Devise::Test::IntegrationHelpers

  before { Rails.application.reload_routes! }

  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:user) { create(:user) }

  it 'logs the exception class, message, and backtrace before rendering the 500 toast' do
    allow_any_instance_of(ProjectsController).to receive(:index)
      .and_raise(RuntimeError, 'kaboom-for-spec')
    allow(Rails.logger).to receive(:error).and_call_original

    sign_in user
    get '/projects', headers: { 'Accept' => 'application/json' }

    expect(response).to have_http_status(:internal_server_error)
    expect(response.parsed_body.dig('toast', 'variant')).to eq('danger')
    expect(Rails.logger).to have_received(:error)
      .with(a_string_including('[helpful_errors] RuntimeError: kaboom-for-spec'))
  end

  it 'includes the exception message for admins and hides it from non-admins' do
    allow_any_instance_of(ProjectsController).to receive(:index)
      .and_raise(RuntimeError, 'kaboom-for-spec')

    sign_in anchor_admin
    get '/projects', headers: { 'Accept' => 'application/json' }
    expect(response.parsed_body.dig('toast', 'message')).to include('kaboom-for-spec')

    sign_in user
    get '/projects', headers: { 'Accept' => 'application/json' }
    expect(response.parsed_body.dig('toast', 'message'))
      .to include('Please contact an administrator if you believe this message is in error')
  end
end
