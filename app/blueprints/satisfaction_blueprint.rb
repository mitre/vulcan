# frozen_string_literal: true

# Lightweight blueprint for Rule satisfaction relationships (satisfies).
#
# PR #717 — comment counts are surfaced so the RuleSatisfactions panel
# can show triagers / commenters where prior conversation lives across
# related rules. Counts are computed against the *related* rule's own
# reviews — comments are NOT auto-inherited, only their counts are
# surfaced for cross-rule discoverability.
#
# Counts use IN-MEMORY filtering on the eager-loaded :reviews
# association (rule.reviews.select { ... }.size, NOT
# rule.reviews.where(...).count) so we don't N+1 with one COUNT per
# related-rule row. The parent controller's set_component eager-loads
# satisfies/satisfied_by → :reviews so the data is available without
# additional queries.
class SatisfactionBlueprint < Blueprinter::Base
  identifier :id
  field :rule_id
  field :srg_id do |rule, _options|
    rule.srg_rule&.version
  end

  field :pending_comment_count do |rule, _options|
    rule.reviews.select do |r|
      r.action == 'comment' &&
        r.responding_to_review_id.nil? &&
        r.triage_status == 'pending'
    end.size
  end

  field :total_comment_count do |rule, _options|
    rule.reviews.select do |r|
      r.action == 'comment' && r.responding_to_review_id.nil?
    end.size
  end
end
