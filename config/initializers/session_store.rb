# frozen_string_literal: true

# AC-10: Server-side session store enables per-user session tracking.
# Cookie-based sessions can't be invalidated server-side; ActiveRecord store can.
Rails.application.config.session_store :active_record_store,
                                       key: '_vulcan_session',
                                       secure: ENV.fetch('RAILS_FORCE_SSL', 'true').downcase != 'false',
                                       httponly: true,
                                       same_site: :lax
