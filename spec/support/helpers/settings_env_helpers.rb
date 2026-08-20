# frozen_string_literal: true

# Shared helper for specs that need Settings loaded against overridden ENV.
#
# Runs the block with ENV overridden and Settings reloaded to reflect it,
# then reloads Settings again AFTER ClimateControl restores the real ENV so
# the modified state never leaks to later specs in the parallel worker (a
# reloaded-but-not-restored Settings is a seed-order flake).
#
# The restore MUST run in the ensure (after ClimateControl exits). An RSpec
# `after` hook cannot do it: after-hooks run inside example.run, i.e. still
# inside the modify block, so they would reload the MODIFIED ENV and re-poison
# global Settings.
module SettingsEnvHelpers
  def with_settings_env(**overrides)
    ClimateControl.modify(**overrides) do
      Settings.reload!
      yield
    end
  ensure
    Settings.reload!
  end
end

RSpec.configure do |config|
  config.include SettingsEnvHelpers, file_path: %r{spec/config/}
end
