# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'No hardcoded hex colors in Vue scoped styles' do
  let(:vue_dir) { Rails.root.join('app/javascript/components') }

  let(:vue_files_with_scoped_styles) do
    Dir.glob(vue_dir.join('**/*.vue')).select do |path|
      File.read(path).include?('<style')
    end
  end

  # Hex values that are acceptable without CSS variables:
  # - #fff / #ffffff (white — not semantic)
  # - Fallback values inside var() like var(--x, #abc) — already centralized
  let(:hex_pattern) { /#[0-9a-fA-F]{3,8}\b/ }

  it 'counts hardcoded hex in scoped styles (baseline tracking)' do
    total = 0
    vue_files_with_scoped_styles.each do |path|
      content = File.read(path)
      style_block = content[%r{<style[^>]*>(.+?)</style>}m, 1] || ''
      lines = style_block.lines.reject { |l| l.include?('var(') }
      hex_lines = lines.grep(hex_pattern)
      total += hex_lines.size
    end
    # Track progress: this number should decrease over time
    # Starting point was ~75, target is 0
    expect(total).to be <= 12,
                     "#{total} hardcoded hex values remain in Vue scoped styles " \
                     '(residual: code editor, diff highlighting, focus ring — see spec comments)'
  end
end
