# frozen_string_literal: true

require 'rails_helper'

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
        file: file_path.to_s.sub("#{Rails.root}/", ''),
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
      fail "Found #{all_violations.size} hardcoded color(s) in Vue scoped styles:\n#{report}\n\n" \
           "Replace with --vulcan-* or --triage-* CSS variables from application.scss."
    end
  end

  it 'no standalone CSS files contain hardcoded colors outside of var() fallbacks' do
    css_files = Dir.glob(JS_DIR.join('styles/**/*.css'))
    all_violations = css_files.flat_map { |f| find_hardcoded_colors_in_css(f) }

    if all_violations.any?
      report = all_violations.map { |v| "  #{v[:file]}:#{v[:line]} — #{v[:content]}" }.join("\n")
      fail "Found #{all_violations.size} hardcoded color(s) in CSS files:\n#{report}\n\n" \
           "Replace with --vulcan-* or --triage-* CSS variables from application.scss."
    end
  end
end
