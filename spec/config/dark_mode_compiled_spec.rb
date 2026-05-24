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

    it 'overrides body background-color in dark mode' do
      decls = declarations_for('[data-bs-theme="dark"] body')
      bg = decls.find { |d| d.include?('background-color') }
      expect(bg).to be_present,
                    'Missing [data-bs-theme="dark"] body { background-color } — Bootstrap 4 sets body bg to #fff which paints over html'
    end

    it 'overrides body color in dark mode' do
      decls = declarations_for('[data-bs-theme="dark"] body')
      color = decls.find { |d| d.start_with?('color:') }
      expect(color).to be_present,
                       'Missing [data-bs-theme="dark"] body { color } — Bootstrap 4 sets body color to dark text'
    end
  end

  # ── fad.8.2: Outline button dark mode colors ─────────────────────────

  describe 'outline button colors (fad.8.2)' do
    %w[secondary primary success danger warning info].each do |variant|
      it "has dark override for .btn-outline-#{variant}" do
        selector = "[data-bs-theme=\"dark\"] .btn-outline-#{variant}"
        decls = declarations_for(selector)
        color_decl = decls.find { |d| d.start_with?('color:') }
        border_decl = decls.find { |d| d.include?('border-color') }
        expect(color_decl).to be_present,
                              "Missing color override for #{selector} — outline text is invisible on dark bg"
        expect(border_decl).to be_present,
                               "Missing border-color override for #{selector} — outline border invisible on dark bg"
      end
    end
  end

  # ── fad.8.3: Navbar link opacity + table header bg ─────────────────

  describe 'navbar + table header (fad.8.3)' do
    it 'overrides .navbar-dark .nav-link color for better legibility' do
      decls = declarations_for('[data-bs-theme="dark"] .navbar-dark .nav-link')
      color_decl = decls.find { |d| d.start_with?('color:') }
      expect(color_decl).to be_present,
                            'Missing .navbar-dark .nav-link color override — 50% opacity too dim'
    end

    it 'adds background to thead th for row differentiation' do
      decls = declarations_for('[data-bs-theme="dark"] thead th')
      bg_decl = decls.find { |d| d.include?('background-color') }
      expect(bg_decl).to be_present,
                         'Missing thead th background-color — headers indistinguishable from body rows'
    end
  end

  # ── fad.8.4: Badge dark mode desaturation ──────────────────────────

  describe 'badge colors (fad.8.4)' do
    %w[warning info success danger secondary].each do |variant|
      it "has dark override for .badge-#{variant}" do
        selector = "[data-bs-theme=\"dark\"] .badge-#{variant}"
        decls = declarations_for(selector)
        expect(decls).not_to be_empty,
                             "Missing dark override for #{selector} — saturated badges cause eye strain on dark bg (Material Design)"
      end
    end
  end

  # ── fad.8.5: Sidebar surface differentiation ────────────────────────

  describe 'sidebar differentiation (fad.8.5)' do
    it 'gives .left-sidebar-column a background in dark mode' do
      decls = declarations_for('[data-bs-theme="dark"] .left-sidebar-column')
      bg_decl = decls.find { |d| d.include?('background-color') }
      expect(bg_decl).to be_present,
                         'Missing .left-sidebar-column background — sidebar indistinguishable from main content'
    end
  end

  # ── fad.8.6: Semantic highlight variables for dark mode ──────────────

  describe 'semantic highlight variables (fad.8.6)' do
    %w[highlight-selected highlight-added highlight-removed highlight-error highlight-success].each do |name|
      it "defines --vulcan-#{name} in dark mode" do
        decls = declarations_for('[data-bs-theme="dark"]')
        var_decl = decls.find { |d| d.include?("--vulcan-#{name}") }
        expect(var_decl).to be_present,
                            "Missing --vulcan-#{name} in dark mode — hardcoded highlight colors won't adapt"
      end
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

  # ── fad.6: Triage workspace + custom components ─────────────────────

  describe 'triage workspace (fad.6)' do
    it 'has dark override for triage row tint opacity' do
      decls = declarations_for('[data-bs-theme="dark"] .triage-bg')
      expect(decls).not_to be_empty,
                           'Missing .triage-bg dark override (row tints need opacity adjustment)'
    end

    it 'has no hardcoded white BACKGROUNDS in scoped styles' do
      vue_dir = Rails.root.join('app/javascript/components')
      offenders = []
      Dir.glob(vue_dir.join('**/*.vue')).each do |path|
        content = File.read(path)
        style_block = content[%r{<style[^>]*>(.+?)</style>}m, 1] || ''
        lines = style_block.lines.reject { |l| l.include?('var(') }
        bg_white = lines.grep(/background(-color)?:\s*(#fff\b|white\s*;)/)
        bg_white.each do |line|
          offenders << "#{File.basename(path)}: #{line.strip}"
        end
      end
      expect(offenders).to be_empty,
                           "Hardcoded white backgrounds in scoped styles:\n#{offenders.join("\n")}"
    end
  end
end
