# frozen_string_literal: true

# Handles server-side consent acknowledgment for NIST AC-8 compliance.
# Stores acknowledgment timestamp in the Rails session.
#
# Authentication is intentionally skipped: AC-8 requires users to
# acknowledge consent BEFORE logging in (the modal blocks the login page).
# The acknowledgment is preserved across Devise's session reset via
# SessionsController#create.
class ConsentController < ApplicationController
  skip_before_action :authenticate_user!

  def acknowledge
    session[:consent_acknowledged_at] = Time.current.iso8601
    head :ok
  end
end
