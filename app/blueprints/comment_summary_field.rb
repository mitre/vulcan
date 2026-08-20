# frozen_string_literal: true

# Per-requirement comment summary shared by RuleBlueprint and
# AuthoredSrgRuleBlueprint — one definition of "open" so the navigator
# badges can never disagree between document kinds.
#
# `open` = comments not yet adjudicated (pending OR triaged-but-not-yet-
# closed OR needs_clarification), including replies under those open
# parents. Computed in-memory against the eager-loaded :reviews
# association so it adds zero queries.
module CommentSummaryField
  def self.summarize(rule)
    comments = rule.reviews.select { |r| r.action == 'comment' }
    top_level = comments.select { |r| r.responding_to_review_id.nil? }
    open_root_ids = top_level.reject { |r| r.adjudicated_at.present? }.map(&:id)

    children_by_parent = comments.reject { |r| r.responding_to_review_id.nil? }
                                 .group_by(&:responding_to_review_id)
    open_count = open_root_ids.size
    queue = open_root_ids.dup
    visited = Set.new(open_root_ids)
    until queue.empty?
      current = queue.shift
      (children_by_parent[current] || []).each do |child|
        next if visited.include?(child.id)

        visited << child.id
        queue << child.id
        open_count += 1
      end
    end

    { open: open_count, total: comments.size }
  end
end
