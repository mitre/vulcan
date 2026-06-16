# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Triage tints CSS — Layer 2 semantic mapping' do
  let(:css_source) { Rails.root.join('app/javascript/styles/triage-tints.css').read }

  it 'references --vulcan-* variables for all triage status base colors' do
    mappings = {
      'concur' => 'success',
      'non-concur' => 'danger',
      'concur-with-comment' => 'primary',
      'informational' => 'warning',
      'pending' => 'secondary',
      'withdrawn' => 'purple',
      'duplicate' => 'teal',
      'addressed-by' => 'indigo'
    }
    mappings.each do |triage_key, vulcan_key|
      expect(css_source).to include("--triage-#{triage_key}: var(--vulcan-#{vulcan_key})"),
                            "--triage-#{triage_key} should reference --vulcan-#{vulcan_key}"
    end
  end

  it 'has zero hardcoded hex values in --triage-* definitions' do
    triage_lines = css_source.lines.select { |l| l.strip.start_with?('--triage-') }
    hex_lines = triage_lines.grep(/#[0-9a-fA-F]{3,8}/)
    expect(hex_lines).to be_empty,
                         "Found hardcoded hex in --triage-* definitions:\n#{hex_lines.join}"
  end

  it 'has data-attribute selectors for every triage status' do
    Review::TRIAGE_STATUSES.each do |status|
      expect(css_source).to include("[data-triage=\"#{status}\"]"),
                            "Missing [data-triage=\"#{status}\"] selector in triage-tints.css"
    end
  end

  it 'each data-attribute selector sets --status-color and --status-tint' do
    Review::TRIAGE_STATUSES.reject { |s| s == 'pending' }.each do |status|
      block = css_source[/\[data-triage="#{status}"\][^{]*\{[^}]+\}/m]
      expect(block).to be_present, "No data-triage block for #{status}"
      expect(block).to include('--status-color'), "#{status} block missing --status-color"
      expect(block).to include('--status-tint'), "#{status} block missing --status-tint"
    end
  end
end
