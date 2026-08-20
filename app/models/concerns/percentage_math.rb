# frozen_string_literal: true

# Percentage helper for dashboard aggregates. Returns nil — never a
# fabricated 0.0 — when the denominator is zero, so clients can
# distinguish "0% complete" from "nothing to complete".
module PercentageMath
  def percentage_of(part, whole)
    return nil if whole.zero?

    ((part.to_f / whole) * 100).round(1)
  end
end
