# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dark mode CSS foundation' do
  let(:scss_source) { Rails.root.join('app/javascript/application.scss').read }

  it 'defines [data-bs-theme="dark"] override block' do
    expect(scss_source).to include('[data-bs-theme="dark"]'),
                           'Missing dark mode selector in application.scss'
  end

  it 'overrides body-level semantic variables in dark mode' do
    %w[body-bg body-color border-color link-color].each do |var|
      expect(scss_source).to include("--vulcan-#{var}"),
                             "Missing --vulcan-#{var} in dark mode overrides"
    end
  end

  it 'defines body-level semantic variables in light mode :root' do
    %w[body-bg body-color border-color link-color].each do |var|
      expect(scss_source).to match(/^:root.*--vulcan-#{var}/m),
                             "Missing --vulcan-#{var} in :root light mode"
    end
  end
end
