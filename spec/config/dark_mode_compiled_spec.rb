# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dark mode compiled CSS verification' do
  let(:compiled_css) do
    Rails.root.join('app/assets/builds/application.css').read
  end

  # Helper: extract all property declarations under a given selector
  # from compiled CSS. Returns array of "property: value" strings.
  # Handles both quoted and unquoted attribute selectors since Sass
  # strips quotes during compilation.
  def declarations_for(selector)
    unquoted = selector.delete('"')
    escaped = Regexp.escape(unquoted)
    # Match both standalone and grouped (comma-separated) selectors
    results = []
    compiled_css.scan(/([^{}]*#{escaped}[^{]*)\{([^}]+)\}/m) do |_sel, block|
      results.concat(block.strip.split(';').map(&:strip).reject(&:empty?))
    end
    results
  end

  # ── fad.1: Foundation variables ─────────────────────────────────────

  describe 'foundation (fad.1)' do
    it 'sets color-scheme: dark under [data-bs-theme="dark"]' do
      decls = declarations_for('[data-bs-theme="dark"]')
      expect(decls.any? { |d| d.include?('color-scheme') && d.include?('dark') }).to be(true),
                                                                                     'Missing color-scheme: dark in [data-bs-theme="dark"] block'
    end

    it 'overrides --vulcan-body-bg to a dark value' do
      decls = declarations_for('[data-bs-theme="dark"]')
      bg_decl = decls.find { |d| d.include?('--vulcan-body-bg') }
      expect(bg_decl).to be_present, 'Missing --vulcan-body-bg override in dark mode'
      expect(bg_decl).not_to include('#fff'), '--vulcan-body-bg should not be white in dark mode'
    end

    it 'sets background-color on [data-bs-theme="dark"] body' do
      decls = declarations_for('[data-bs-theme="dark"]')
      expect(decls.any? { |d| d.include?('background-color') }).to be(true),
                                                                   'Dark mode block should set background-color'
    end
  end

  # ── fad.2: Component backgrounds ────────────────────────────────────

  describe 'component backgrounds (fad.2)' do
    %w[card modal-content dropdown-menu list-group-item popover].each do |component|
      it "has dark override for .#{component}" do
        selector = "[data-bs-theme=\"dark\"] .#{component}"
        decls = declarations_for(selector)
        expect(decls.any? { |d| d.include?('background-color') }).to be(true),
                                                                     "Missing background-color for #{selector}"
      end
    end

    it 'has dark override for .dropdown-item hover' do
      decls = declarations_for('[data-bs-theme="dark"] .dropdown-item:hover')
      expect(decls).not_to be_empty, 'Missing .dropdown-item:hover dark override'
    end

    it 'has dark override for .bg-light utility' do
      decls = declarations_for('[data-bs-theme="dark"] .bg-light')
      expect(decls.any? { |d| d.include?('background-color') }).to be(true)
    end
  end

  # ── fad.3: Form controls + tables ───────────────────────────────────

  describe 'form controls and tables (fad.3)' do
    it 'has dark override for .form-control' do
      decls = declarations_for('[data-bs-theme="dark"] .form-control')
      bg = decls.find { |d| d.include?('background-color') }
      expect(bg).to be_present, 'Missing .form-control background-color dark override'
      expect(bg).not_to include('#fff'), '.form-control should not be white in dark mode'
    end

    it 'has dark override for .table color' do
      decls = declarations_for('[data-bs-theme="dark"] .table')
      expect(decls.any? { |d| d.include?('color') }).to be(true),
                                                        'Missing .table color dark override'
    end

    it 'has dark override for .page-link' do
      decls = declarations_for('[data-bs-theme="dark"] .page-link')
      expect(decls).not_to be_empty, 'Missing .page-link dark override'
    end
  end

  # ── fad.4: Navigation ───────────────────────────────────────────────

  describe 'navigation (fad.4)' do
    it 'has dark override for .breadcrumb' do
      decls = declarations_for('[data-bs-theme="dark"] .breadcrumb')
      expect(decls.any? { |d| d.include?('background-color') }).to be(true)
    end

    it 'has dark override for .nav-tabs' do
      decls = declarations_for('[data-bs-theme="dark"] .nav-tabs')
      expect(decls).not_to be_empty
    end
  end

  # ── fad.5: Editors ──────────────────────────────────────────────────

  describe 'editors (fad.5)' do
    it 'has dark override for .CodeMirror' do
      decls = declarations_for('[data-bs-theme="dark"] .CodeMirror')
      bg = decls.find { |d| d.include?('background-color') }
      expect(bg).to be_present, 'Missing .CodeMirror background-color dark override'
    end

    it 'has dark override for .editor-toolbar' do
      decls = declarations_for('[data-bs-theme="dark"] .editor-toolbar')
      expect(decls.any? { |d| d.include?('background-color') }).to be(true)
    end

    it 'has dark override for .CodeMirror-cursor' do
      decls = declarations_for('[data-bs-theme="dark"] .CodeMirror-cursor')
      expect(decls).not_to be_empty, 'Missing cursor color for dark mode editor'
    end
  end
end
