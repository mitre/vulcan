# frozen_string_literal: true

require 'rails_helper'
require 'puma'
require 'puma/configuration'

# REQUIREMENT: config/puma.rb must honor WEB_CONCURRENCY. The stock Rails puma.rb
# documents the knob but ships no `workers` line, so WEB_CONCURRENCY is silently
# ignored (every dyno runs single-mode regardless of the setting). This guards
# the fix: unset => single mode (the container default, unchanged); set => that
# many workers with copy-on-write preloading.
RSpec.describe 'config/puma.rb worker configuration' do
  def resolved_puma_options
    config = Puma::Configuration.new(config_files: [Rails.root.join('config/puma.rb').to_s])
    config.load
    config.clamp
    config.options
  end

  it 'runs single-mode (0 workers, no preload) when WEB_CONCURRENCY is unset' do
    ClimateControl.modify(WEB_CONCURRENCY: nil) do
      options = resolved_puma_options
      expect(options[:workers]).to eq(0)
      expect(options[:preload_app]).to be(false)
    end
  end

  it 'runs cluster mode with copy-on-write preloading when WEB_CONCURRENCY is set' do
    ClimateControl.modify(WEB_CONCURRENCY: '2') do
      options = resolved_puma_options
      expect(options[:workers]).to eq(2)
      expect(options[:preload_app]).to be(true)
    end
  end
end
