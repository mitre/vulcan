# frozen_string_literal: true

# Handles server-side consent acknowledgment for NIST AC-8 compliance.
# Stores acknowledgment timestamp in the Rails session, tying consent
# to the authentication lifecycle rather than browser localStorage.
class ConsentController < ApplicationController
  before_action :authenticate_user!

  def acknowledge
    session[:consent_acknowledged_at] = Time.current.iso8601
    head :ok
  end
end
