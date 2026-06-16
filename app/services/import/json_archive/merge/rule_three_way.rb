# frozen_string_literal: true

module Import
  module JsonArchive
    module Merge
      # Per-field 3-way merge against an SRG baseline. Given (srg_baseline,
      # ours, theirs) for a single field, returns one of four verdicts:
      #
      #   :no_change — ours == theirs (both same value, baseline irrelevant)
      #   :theirs    — ours == baseline; only theirs diverged
      #   :ours      — theirs == baseline; only ours diverged
      #   :conflict  — both ours and theirs diverged from baseline differently
      #
      # When srg_baseline is nil the algorithm degrades to 2-way: equal →
      # :no_change, different → :conflict. Callers (RuleFieldDiffer +
      # Analyzer) layer Strategy on top to map :conflict to a concrete
      # resolution.
      class RuleThreeWay
        def initialize(srg_baseline:, ours:, theirs:)
          @srg_baseline = srg_baseline
          @ours = ours || {}
          @theirs = theirs || {}
        end

        def resolve(field)
          ours_val = @ours[field]
          theirs_val = @theirs[field]

          return :no_change if ours_val == theirs_val

          return :conflict if fallback_to_two_way? || !@srg_baseline.key?(field)

          srg_val = @srg_baseline[field]

          return :theirs if ours_val == srg_val
          return :ours if theirs_val == srg_val

          :conflict
        end

        def fallback_to_two_way?
          @srg_baseline.nil?
        end
      end
    end
  end
end
