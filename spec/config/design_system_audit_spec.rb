# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/NoExpectationExample
# Pattern constants are module-level audit config; defining them at file
# scope would make them visible to other specs unnecessarily. The `it`
# blocks rely on `raise` to surface violations with a formatted report —
# the absence of a raised exception IS the passing assertion.
RSpec.describe 'Vulcan Design System audit' do
  JS_DIR = Rails.root.join('app/javascript')

  HEX_PATTERN = /\#[0-9a-fA-F]{3,8}\b/
  RGBA_PATTERN = /rgba?\s*\(/
  HSLA_PATTERN = /hsla?\s*\(/

  def extract_style_blocks(vue_content)
    vue_content.scan(%r{<style[^>]*>(.*?)</style>}m).flatten
  end

  def scan_lines_for_colors(lines, file_path)
    violations = []
    lines.each_with_index do |line, idx|
      stripped = line.strip
      next if stripped.start_with?('//', '*', '/*')
      next if stripped.include?('var(--')

      has_color = stripped.match?(HEX_PATTERN) ||
                  stripped.match?(RGBA_PATTERN) ||
                  stripped.match?(HSLA_PATTERN)
      next unless has_color

      violations << {
        file: file_path.to_s.sub(Rails.root.join.to_s, ''),
        line: idx + 1,
        content: stripped
      }
    end
    violations
  end

  def find_hardcoded_colors_in_vue(file_path)
    content = File.read(file_path)
    style_blocks = extract_style_blocks(content)
    style_blocks.flat_map { |block| scan_lines_for_colors(block.lines, file_path) }
  end

  def find_hardcoded_colors_in_css(file_path)
    content = File.read(file_path)
    scan_lines_for_colors(content.lines, file_path)
  end

  it 'no Vue scoped styles contain hardcoded colors outside of var() fallbacks' do
    vue_files = Dir.glob(JS_DIR.join('components/**/*.vue'))
    all_violations = vue_files.flat_map { |f| find_hardcoded_colors_in_vue(f) }

    if all_violations.any?
      report = all_violations.map { |v| "  #{v[:file]}:#{v[:line]} — #{v[:content]}" }.join("\n")
      raise "Found #{all_violations.size} hardcoded color(s) in Vue scoped styles:\n#{report}\n\n" \
            'Replace with --vulcan-* or --triage-* CSS variables from application.scss.'
    end
  end

  it 'no standalone CSS files contain hardcoded colors outside of var() fallbacks' do
    css_files = Dir.glob(JS_DIR.join('styles/**/*.css'))
    all_violations = css_files.flat_map { |f| find_hardcoded_colors_in_css(f) }

    if all_violations.any?
      report = all_violations.map { |v| "  #{v[:file]}:#{v[:line]} — #{v[:content]}" }.join("\n")
      raise "Found #{all_violations.size} hardcoded color(s) in CSS files:\n#{report}\n\n" \
            'Replace with --vulcan-* or --triage-* CSS variables from application.scss.'
    end
  end

  # Spacing: no arbitrary px values above 4px for margin/padding/gap in scoped styles.
  # Sub-pixel adjustments (1-4px) are acceptable for micro-alignment.
  # Larger values should use rem or Bootstrap spacing utilities.
  LARGE_PX_PATTERN = /(?:margin|padding|gap)\s*:\s*[^;]*\b([5-9]|\d{2,})px/

  def find_large_px_spacing(file_path)
    content = File.read(file_path)
    style_blocks = extract_style_blocks(content)
    violations = []

    style_blocks.each do |block|
      block.lines.each_with_index do |line, idx|
        stripped = line.strip
        next if stripped.start_with?('//', '*', '/*')

        next unless stripped.match?(LARGE_PX_PATTERN)

        violations << {
          file: file_path.to_s.sub(Rails.root.join.to_s, ''),
          line: idx + 1,
          content: stripped
        }
      end
    end
    violations
  end

  it 'no Vue scoped styles use arbitrary px > 4 for margin/padding/gap' do
    vue_files = Dir.glob(JS_DIR.join('components/**/*.vue'))
    all_violations = vue_files.flat_map { |f| find_large_px_spacing(f) }

    if all_violations.any?
      report = all_violations.map { |v| "  #{v[:file]}:#{v[:line]} — #{v[:content]}" }.join("\n")
      raise "Found #{all_violations.size} arbitrary px spacing value(s) > 4px:\n#{report}\n\n" \
            'Use rem values or Bootstrap spacing utilities (p-1, m-2, gap-3, etc.).'
    end
  end

  describe 'CSS variable completeness' do
    let(:scss_content) { File.read(JS_DIR.join('application.scss')) }
    let(:root_block) do
      scss_content.match(/^:root\s*\{(.*?)^\}/m)&.captures&.first || ''
    end

    REQUIRED_LIGHT_MODE_VARS = %w[
      --vulcan-hover-bg
      --vulcan-hover-bg-light
      --vulcan-divider
      --vulcan-text-muted
      --vulcan-active-tint
      --vulcan-secondary-color
      --vulcan-tertiary-color
      --vulcan-border-color-translucent
      --vulcan-input-bg
      --vulcan-input-color
      --vulcan-input-border-color
      --vulcan-input-placeholder-color
      --vulcan-input-disabled-bg
      --vulcan-link-hover-color
    ].freeze

    it 'all design system variables are defined in :root (light mode)' do
      missing = REQUIRED_LIGHT_MODE_VARS.reject { |var| root_block.include?(var) }

      if missing.any?
        raise "#{missing.size} CSS variable(s) missing from :root in application.scss:\n  " \
              "#{missing.join("\n  ")}\n\n" \
              "Variables defined only in [data-bs-theme=\"dark\"] have no value in light mode.\n" \
              'Add them to the :root block with appropriate light-mode values.'
      end
    end
  end

  describe '.rule-form-field does not override Bootstrap form-group spacing' do
    let(:scss_content) { File.read(JS_DIR.join('application.scss')) }

    it 'does not set margin-bottom (Bootstrap .form-group owns vertical spacing)' do
      rule_form_field_block = scss_content.match(/\.rule-form-field\s*\{([^}]+)\}/m)&.captures&.first || ''
      expect(rule_form_field_block).not_to include('margin-bottom'),
                                           ".rule-form-field sets margin-bottom, which overrides Bootstrap's " \
                                           '.form-group margin-bottom: 1rem. Remove it — let .form-group own spacing.'
    end
  end

  describe 'dark mode tint completeness' do
    let(:scss_content) { File.read(JS_DIR.join('application.scss')) }
    let(:dark_block) do
      scss_content.match(/\[data-bs-theme="dark"\]\s*\{(.*)\Z/m)&.captures&.first || ''
    end

    REQUIRED_DARK_TINTS = %w[
      --vulcan-purple-tint
      --vulcan-teal-tint
      --vulcan-indigo-tint
    ].freeze

    it 'extended palette tints are defined in dark mode (used by triage row tints)' do
      missing = REQUIRED_DARK_TINTS.reject { |var| dark_block.include?(var) }

      if missing.any?
        raise "#{missing.size} tint variable(s) missing from dark mode block:\n  " \
              "#{missing.join("\n  ")}\n\n" \
              'Without dark mode tints, withdrawn/duplicate/addressed-by row tints are invisible.'
      end
    end
  end

  describe 'dark mode DRY — variant overrides use @each loops' do
    let(:scss_content) { File.read(JS_DIR.join('application.scss')) }
    let(:dark_block) do
      scss_content.match(/\[data-bs-theme="dark"\]\s*\{(.*)\Z/m)&.captures&.first || ''
    end

    it 'badge variants use @each loop, not individual blocks' do
      individual_badges = dark_block.scan(/\.badge-(warning|info|success|danger|secondary)\s*\{/)
      expect(individual_badges).to be_empty,
                                   "Found #{individual_badges.size} individual .badge-* blocks in dark mode. " \
                                   'Use ONE @each loop per Bootstrap 5.3 pattern.'
    end

    it 'outline button variants use @each loop, not individual blocks' do
      individual_btns = dark_block.scan(/\.btn-outline-(secondary|primary|success|danger|warning|info)\s*\{/)
      expect(individual_btns).to be_empty,
                                 "Found #{individual_btns.size} individual .btn-outline-* blocks in dark mode. " \
                                 'Use ONE @each loop per Bootstrap 5.3 pattern.'
    end
  end

  describe 'BvConfig global defaults' do
    let(:config_content) { File.read(JS_DIR.join('config/bootstrapVueConfig.js')) }

    it 'sets BTable striped: true for consistent zebra striping' do
      expect(config_content).to include('BTable'),
                                'bootstrapVueConfig.js missing BTable config — add { striped: true } for consistent zebra striping'
      expect(config_content).to include('striped'),
                                'BTable config missing striped: true'
    end
  end

  describe 'no raw Bootstrap CSS variables in scoped styles' do
    BOOTSTRAP_RAW_VARS = /var\(--(?:primary|secondary|success|danger|warning|info|light|dark)\b[^-]/

    def find_bootstrap_vars_in_vue(file_path)
      content = File.read(file_path)
      style_blocks = extract_style_blocks(content)
      violations = []

      style_blocks.each do |block|
        block.lines.each_with_index do |line, idx|
          stripped = line.strip
          next if stripped.start_with?('//', '*', '/*')
          next unless stripped.match?(BOOTSTRAP_RAW_VARS)

          violations << {
            file: file_path.to_s.sub(Rails.root.join.to_s, ''),
            line: idx + 1,
            content: stripped
          }
        end
      end
      violations
    end

    it 'scoped styles use --vulcan-* not raw Bootstrap --primary/--info/etc' do
      vue_files = Dir.glob(JS_DIR.join('components/**/*.vue'))
      all_violations = vue_files.flat_map { |f| find_bootstrap_vars_in_vue(f) }

      if all_violations.any?
        report = all_violations.map { |v| "  #{v[:file]}:#{v[:line]} — #{v[:content]}" }.join("\n")
        raise "Found #{all_violations.size} raw Bootstrap CSS variable(s) in scoped styles:\n#{report}\n\n" \
              'Use --vulcan-* design system variables instead of raw Bootstrap --primary, --info, etc.'
      end
    end
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock, RSpec/NoExpectationExample
