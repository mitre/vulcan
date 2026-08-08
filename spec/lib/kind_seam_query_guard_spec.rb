# frozen_string_literal: true

require 'rails_helper'

# ===========================================================================
# REQUIREMENT: the centralization invariant for requirement-scoped
# triage/comment/disposition queries. Rule is the STIG STI subclass, so
# `Rule.where(component_id:)` or traversing `component.rules` structurally
# excludes authored SrgRules — every such query must route through the kind
# seam (BaseRule.live_for_components / Component#requirements). This guard
# pins the files that have already been migrated; a reintroduction fails
# here with the file and line, not months later as silently missing SRG
# comments in an export.
# ===========================================================================
RSpec.describe 'Kind-seam query invariant' do
  guarded_files = %w[
    app/lib/disposition_matrix_export.rb
    app/services/comment_query_service.rb
    app/models/review.rb
    app/models/reaction.rb
  ]

  # The STI-subclass query shapes that structurally drop SrgRules. Only live
  # code is matched — comment prose legitimately names the anti-pattern when
  # explaining the seam (comment_query_service.rb does exactly that), and a
  # commented-out violation still fails here the moment it is reactivated.
  forbidden_patterns = {
    'Rule.where(component_id:)' => /\bRule\s*\.\s*where\s*\(\s*component_id/,
    'component.rules traversal' => /\bcomponent\s*\.\s*rules\b/
  }

  guarded_files.each do |relative_path|
    describe relative_path do
      let(:lines) { Rails.root.join(relative_path).read.lines }

      forbidden_patterns.each do |label, pattern|
        it "does not use #{label}" do
          offenses = lines.each_with_index.filter_map do |line, index|
            code = line.sub(/#.*/, '')
            "#{relative_path}:#{index + 1}: #{line.strip}" if code.match?(pattern)
          end

          expect(offenses).to be_empty, <<~MSG
            Requirement-scoped queries must go through the kind seam
            (BaseRule.live_for_components / Component#requirements) — Rule is
            the STIG STI subclass and structurally excludes authored SrgRules.
            Offending lines:
            #{offenses.join("\n")}
          MSG
        end
      end
    end
  end
end
