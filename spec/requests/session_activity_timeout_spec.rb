# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS (Devise :timeoutable — AC-12 inactivity timeout):
#
# 1. A session ends after `Devise.timeout_in` of INACTIVITY, not a fixed
#    interval measured from sign-in. A user who makes an authenticated request
#    every `timeout_in / 4` must therefore never be signed out, however long
#    they keep working.
# 2. A session that sees NO activity for longer than `timeout_in` must be
#    signed out. (This is the counterweight to requirement 1: a "fix" that
#    merely disables the timeout would satisfy 1 and fail here.)
# 3. The inactivity clock lives in the server-side session row, so the
#    `sessions` row for the live session must actually be persisted on each
#    request — its `last_request_at` and `updated_at` must advance. Asserting
#    only the observable 200/401 would pass against any store that happened to
#    keep the clock somewhere else.
# 4. A request that leaves the session genuinely unchanged must NOT write the
#    row. Requirements 1-3 can be satisfied by forcing every session dirty on
#    every request; that trades a per-request UPDATE for correctness and is not
#    what we want.
#
# The sign-in is a real POST /users/sign_in rather than
# Devise::Test::IntegrationHelpers#sign_in: the test helper's own Warden
# set_user writes a top-level session key on the first request, which shifts
# the symptom by one interval and can hide a dropped session write.
#
# No `remember_me` is sent anywhere in this file on purpose. Devise's
# timeoutable hook skips the timeout check entirely while a remember cookie is
# live, so a remember-me sign-in would mask every assertion below.
RSpec.describe 'Session inactivity timeout' do
  include ActiveSupport::Testing::TimeHelpers

  before { Rails.application.reload_routes! }

  # No `travel_back`: Rails 7+ ActiveSupport::Testing::TimeHelpers auto-restores
  # time after each example (verified; see Rails/RedundantTravelBack cop and the
  # same note in spec/requests/rack_attack_spec.rb).

  # Created before `user` so that `user` is never the first user in the
  # database: first-user-admin would otherwise promote it (see CLAUDE.md on
  # `let!` ordering).
  let!(:anchor_admin) { create(:user, admin: true) }

  let(:password) { 'S3cure!#Pass999' }
  let!(:user) { create(:user, password: password, password_confirmation: password) }

  let(:interval) { Devise.timeout_in / 4 }

  def sign_in_through_the_form
    post user_session_path, params: { user: { email: user.email, password: password } }
    get '/api/auth/me', as: :json
    expect(response).to have_http_status(:ok)
  end

  # The cookie carries the public session id; the row is keyed by its private
  # (hashed) form. Scoped lookup rather than `Session.last` keeps this
  # parallel-safe.
  def session_record
    raw_session_id = cookies['_vulcan_session']
    return nil if raw_session_id.blank?

    ActiveRecord::SessionStore::Session.find_by(
      session_id: Rack::Session::SessionId.new(raw_session_id).private_id
    )
  end

  # Devise :timeoutable stores the inactivity clock nested inside the Warden
  # scope hash, which is what makes it an in-place mutation of the session.
  def persisted_last_request_at(record)
    record.data['warden.user.user.session']&.fetch('last_request_at', nil)
  end

  def count_session_updates
    updates = 0
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      updates += 1 if payload[:sql].include?('UPDATE "sessions"')
    end
    yield
    updates
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  describe 'a user who stays active' do
    it 'is never signed out while making a request every quarter of timeout_in' do
      sign_in_through_the_form

      # Two full timeout windows' worth of activity: long enough that a
      # fixed-interval-from-sign-in expiry cannot survive it.
      requests = (2 * Devise.timeout_in / interval).to_i

      requests.times do |i|
        travel interval
        get '/api/auth/me', as: :json

        elapsed = (i + 1) * interval
        expect(response).to have_http_status(:ok),
                            "signed out after #{elapsed / 60} minutes of activity at " \
                            "#{interval / 60}-minute intervals (timeout_in = " \
                            "#{Devise.timeout_in.inspect}); body: #{response.body[0, 200]}"
      end
    end

    it 'advances the persisted inactivity clock on every request' do
      sign_in_through_the_form

      record = session_record
      expect(record).to be_present, 'no sessions row was found for the signed-in session'

      before_updated_at = record.updated_at
      before_last_request_at = persisted_last_request_at(record)
      expect(before_last_request_at).to be_present,
                                        'Devise :timeoutable never persisted last_request_at'

      travel interval
      get '/api/auth/me', as: :json
      expect(response).to have_http_status(:ok)

      record = session_record
      expect(persisted_last_request_at(record)).to be > before_last_request_at
      expect(record.updated_at).to be > before_updated_at
    end

    it 'writes the sessions row exactly once per request that moves the clock' do
      sign_in_through_the_form

      updates = count_session_updates do
        3.times do
          travel interval
          get '/api/auth/me', as: :json
        end
      end

      expect(updates).to eq(3)
    end

    it 'does not write the sessions row when the session is unchanged' do
      # Devise stores last_request_at with one-second resolution, so requests
      # inside the same frozen second leave the session byte-identical.
      travel_to Time.zone.parse('2026-06-01 12:00:00 UTC')
      sign_in_through_the_form

      updates = count_session_updates do
        3.times { get '/api/auth/me', as: :json }
      end

      expect(updates).to eq(0)
    end
  end

  describe 'a user who goes idle' do
    it 'is signed out once timeout_in passes with no activity' do
      sign_in_through_the_form

      travel Devise.timeout_in + 1.minute
      get '/api/auth/me', as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'stays signed in right up to the edge of timeout_in' do
      sign_in_through_the_form

      travel Devise.timeout_in - 1.minute
      get '/api/auth/me', as: :json

      expect(response).to have_http_status(:ok)
    end
  end
end
