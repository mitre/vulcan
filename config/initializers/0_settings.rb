# frozen_string_literal: true

# We load our settings first so that we can access them
# in other initializers

require_relative '../settings'

# Backfills live on the Settings class so Settings.reload! can re-apply
# them — initializers only run once per boot.
Settings.apply_defaults!
