# frozen_string_literal: true

# Server-side enforcement of the Settings.local_login.enabled policy. The
# sign-in views hide the email/password form when local login is disabled
# (SSO-only), but nothing stopped a crafted POST — so both the HTML Devise
# session path and the JSON /api/auth/login endpoint could still establish a
# session from local credentials. This is the ONE guard both wire to.
module LocalLoginEnforceable
  extend ActiveSupport::Concern

  private

  def require_local_login_enabled!
    return if Settings.local_login.enabled

    if request.format.json? || is_a?(Api::BaseController)
      render_local_login_disabled
    else
      flash.alert = 'Local email/password sign-in is disabled for this instance.'
      redirect_to new_user_session_path
    end
  end

  # 403: the endpoint exists but instance policy forbids local email/password
  # sign-in (SSO-only). Distinct from invalid credentials — the request never
  # reaches password verification. render_problem comes from ErrorRendering
  # (both concerns are mixed into ApplicationController).
  def render_local_login_disabled
    render_problem(
      type: :local_login_disabled, title: 'Local login disabled', status: :forbidden,
      detail: 'This instance is configured for single sign-on; email and password sign-in is disabled.'
    )
  end
end
