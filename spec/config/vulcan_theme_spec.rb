# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Vulcan design system CSS custom properties' do
  let(:scss_source) { Rails.root.join('app/javascript/application.scss').read }

  it 'bridges Bootstrap theme colors to --vulcan-* CSS custom properties' do
    %w[primary secondary success danger warning info light dark].each do |color|
      expect(scss_source).to include("--vulcan-#{color}"),
                             "missing --vulcan-#{color} CSS custom property bridge"
    end
  end

  it 'defines extended palette colors (purple, teal, indigo) for non-Bootstrap statuses' do
    %w[purple teal indigo].each do |color|
      expect(scss_source).to include("--vulcan-#{color}"),
                             "missing --vulcan-#{color} extended palette variable"
    end
  end

  it 'defines tint and text variants for each core color' do
    %w[primary secondary success danger warning info].each do |color|
      expect(scss_source).to include("--vulcan-#{color}-tint"),
                             "missing --vulcan-#{color}-tint variant"
      expect(scss_source).to include("--vulcan-#{color}-text"),
                             "missing --vulcan-#{color}-text variant"
    end
  end

  it 'uses Sass interpolation not hardcoded hex for Bootstrap colors' do
    %w[primary secondary success danger warning info light dark].each do |color|
      expect(scss_source).to match(/--vulcan-#{color}:\s*#\{/),
                             "--vulcan-#{color} should use Sass interpolation, not hardcoded hex"
    end
  end
end
