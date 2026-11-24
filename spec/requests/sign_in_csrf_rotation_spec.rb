# frozen_string_literal: true

require 'rails_helper'

# Every interactive sign-in rotates the session's authenticity token, whatever
# controller calls sign_in: Devise's CSRF cleaner runs only for the
# :authentication event, and Warden records a plain sign_in as :set_user. A
# stateless sign-in (store: false, the personal-access-token path) has no
# session token to rotate, and a caller that names its own event keeps it.
class SignInCsrfRotationProbeController < ApplicationController
  skip_before_action :authenticate_user!

  def plain
    sign_in(probe_user)
    head :ok
  end

  def stateless
    sign_in(probe_user, store: false)
    head :ok
  end

  def named_event
    sign_in(probe_user, event: :set_user)
    head :ok
  end

  private

  def probe_user
    User.find(params[:id])
  end
end

RSpec.describe 'CSRF token rotation on sign-in' do
  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:user) { create(:user) }

  before do
    Rails.application.reload_routes!
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get '/sign_in_probe/:action/:id', controller: 'sign_in_csrf_rotation_probe'
    end
  end

  after do
    Rails.application.routes.disable_clear_and_finalize = false
    Rails.application.reload_routes!
  end

  def session_token_before
    get '/api/auth/csrf', as: :json
    session[:_csrf_token].tap { |token| expect(token).to be_present }
  end

  it 'rotates the token when a controller calls plain sign_in' do
    before_token = session_token_before

    get "/sign_in_probe/plain/#{user.id}"

    expect(response).to have_http_status(:ok)
    expect(session[:_csrf_token]).not_to eq(before_token)
  end

  it 'leaves the token alone for a stateless sign-in (store: false)' do
    before_token = session_token_before

    get "/sign_in_probe/stateless/#{user.id}"

    expect(response).to have_http_status(:ok)
    expect(session[:_csrf_token]).to eq(before_token)
  end

  # The override must not narrow what it overrides.
  # Devise::Controllers::SignInOut#sign_in is public, so an external caller
  # (an engine, a Devise controller, a console) may call it; defining the
  # override under `private` would make it private on ApplicationController
  # and on every descendant, including the DeviseController subclasses.
  it 'leaves Devise sign_in callable from outside the controller' do
    [ApplicationController, SessionsController, Api::AuthController,
     Users::RegistrationsController].each do |controller|
      expect(controller.public_method_defined?(:sign_in)).to be(true),
                                                             "#{controller} made Devise's public sign_in non-public"
    end
  end

  it 'keeps an event the caller names' do
    before_token = session_token_before

    get "/sign_in_probe/named_event/#{user.id}"

    expect(response).to have_http_status(:ok)
    expect(session[:_csrf_token]).to eq(before_token)
  end
end
