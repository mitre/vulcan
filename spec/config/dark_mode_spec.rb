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

  # ── fad.2: Component overrides ──────────────────────────────────────
  describe 'fad.2 — component backgrounds' do
    let(:dark_block) { scss_source[/\[data-bs-theme="dark"\]\s*\{.+/m] }

    %w[card modal-content dropdown-menu list-group-item popover].each do |component|
      it "overrides .#{component} in dark mode" do
        expect(dark_block).to include(".#{component}"),
                              "Missing .#{component} dark mode override"
      end
    end

    it 'overrides .bg-light utility' do
      expect(dark_block).to include('.bg-light')
    end

    it 'overrides .bg-white utility' do
      expect(dark_block).to include('.bg-white')
    end

    it 'overrides alert variants' do
      %w[alert-warning alert-danger alert-success alert-info].each do |alert|
        expect(dark_block).to include(".#{alert}"),
                              "Missing .#{alert} dark mode override"
      end
    end
  end

  # ── fad.3: Form controls + tables ───────────────────────────────────
  describe 'fad.3 — form controls and tables' do
    let(:dark_block) { scss_source[/\[data-bs-theme="dark"\]\s*\{.+/m] }

    it 'overrides .form-control in dark mode' do
      expect(dark_block).to include('.form-control')
    end

    it 'overrides .custom-select in dark mode' do
      expect(dark_block).to include('.custom-select')
    end

    it 'overrides .table in dark mode' do
      expect(dark_block).to include('.table')
    end

    it 'overrides .input-group-text in dark mode' do
      expect(dark_block).to include('.input-group-text')
    end

    it 'overrides .page-link (pagination) in dark mode' do
      expect(dark_block).to include('.page-link')
    end
  end

  # ── fad.4: Navbar, sidebar, breadcrumbs, tabs ──────────────────────
  describe 'fad.4 — navigation' do
    let(:dark_block) { scss_source[/\[data-bs-theme="dark"\]\s*\{.+/m] }

    it 'overrides .breadcrumb in dark mode' do
      expect(dark_block).to include('.breadcrumb')
    end

    it 'overrides .nav-tabs in dark mode' do
      expect(dark_block).to include('.nav-tabs')
    end

    it 'overrides hr border color in dark mode' do
      expect(dark_block).to match(/hr\s*\{/)
    end
  end

  # ── fad.5: EasyMDE + Monaco ─────────────────────────────────────────
  describe 'fad.5 — editors' do
    let(:dark_block) { scss_source[/\[data-bs-theme="dark"\]\s*\{.+/m] }

    it 'overrides .CodeMirror in dark mode' do
      expect(dark_block).to include('.CodeMirror')
    end

    it 'overrides .editor-toolbar in dark mode' do
      expect(dark_block).to include('.editor-toolbar')
    end

    it 'has Monaco theme integration via colorMode' do
      inspec_source = Rails.root.join(
        'app/javascript/components/rules/InspecControlEditor.vue'
      ).read
      expect(inspec_source).to include('colorMode'),
                               'InspecControlEditor should import colorMode'
    end
  end
end
