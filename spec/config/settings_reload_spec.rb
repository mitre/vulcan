# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settings reload' do
  # Settings.reload! rebuilds the instance straight from vulcan.default.yml.
  # Several values exist ONLY as backfills from Settings.apply_defaults!
  # (run by config/initializers/0_settings.rb at boot): the YAML renders
  # them nil when the env var is unset — e.g. smtp.enabled has no `|| false`
  # fallback, top-level oidc.discovery is deliberately absent from the YAML,
  # and the banner color defaults render unquoted (`background_color:
  # #007a33`) so YAML reads them as comments. If reload! does not re-apply
  # the defaults, every later spec in the same process runs against nil
  # sections — the seed-order flake this file pins down.

  # Unset the env vars behind each pinned value so the expected default is
  # deterministic regardless of the developer's .env. with_settings_env
  # reloads Settings inside the modified ENV and restores it afterward, so no
  # modified state leaks to later specs.
  around do |example|
    with_settings_env(
      VULCAN_ENABLE_SMTP: nil,
      VULCAN_CONTACT_EMAIL: nil,
      VULCAN_BANNER_BACKGROUND_COLOR: nil,
      VULCAN_BANNER_TEXT_COLOR: nil,
      VULCAN_CONSENT_CONTENT: nil
    ) { example.run }
  end

  it 'preserves initializer-backfilled defaults across reload!' do
    Settings.reload!

    # Every value here is nil straight from the YAML (no `|| false` on
    # smtp.enabled; no top-level oidc.discovery key; providers section is
    # comment-only; contact_email/consent.content render empty; banner
    # colors render as unquoted `#hex` that YAML reads as a comment). They
    # exist ONLY because apply_defaults! ran — so each assertion fails
    # against the pre-fix reload! that dropped the backfill. Integer/String
    # defaults that the YAML itself renders (lockout.*, password.*) are NOT
    # pinned here: they survive any reload regardless of the fix, so they
    # would not witness the regression. The consistency spec guards those.
    expect(Settings.smtp['enabled']).to be false
    expect(Settings.oidc['discovery']).to be true
    expect(Settings['providers'].to_h).to eq({})
    expect(Settings['contact_email']).to eq('vulcan-support@example.com')
    expect(Settings.banner['background_color']).to eq('#007a33')
    expect(Settings.banner['text_color']).to eq('#ffffff')
    expect(Settings.consent['content']).to eq('')
  end

  it 'is idempotent across repeated reloads' do
    2.times { Settings.reload! }

    expect(Settings.smtp['enabled']).to be false
    expect(Settings['contact_email']).to eq('vulcan-support@example.com')
    expect(Settings.banner['background_color']).to eq('#007a33')
  end
end
