# frozen_string_literal: true

# AC-10: Server-side session store enables per-user session tracking.
# Cookie-based sessions can't be invalidated server-side; ActiveRecord store can.
#
# NOTE: No `secure:` flag here. When config.force_ssl = true (production.rb),
# Rails' ActionDispatch::SSL middleware automatically marks ALL cookies secure.
# Setting `secure:` explicitly here would override Rails' built-in behavior and
# break sessions in test/development (which run over HTTP).
# See: Mastodon, Discourse use the same pattern.
Rails.application.config.session_store :active_record_store,
                                       key: '_vulcan_session',
                                       httponly: true,
                                       same_site: :lax
