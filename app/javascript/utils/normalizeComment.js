/**
 * Normalize a wire-format comment row (CommentRow / CommentQueryService
 * shape, snake_case) into the camelCase shape the shared comment
 * components (CommentItem, CommentBody, CommentActions) consume.
 *
 * The original wire fields are kept alongside (spread), so normalizing
 * an already-normalized row is a no-op — callers may normalize
 * defensively without tracking provenance.
 */
export function normalizeComment(raw) {
  return {
    ...raw,
    ruleId: raw.rule_id ?? null,
    authorName: raw.author_name || raw.commenter_display_name || "",
    authorEmail: raw.commenter_email ?? null,
    text: raw.comment ?? "",
    section: raw.section ?? null,
    triageStatus: raw.triage_status ?? null,
    createdAt: raw.created_at ?? null,
    // null (not {}) when absent — {} passes CommentThread's v-if but
    // fails ReactionButtons' validator. The wire always sends
    // { up, down, mine } when reaction data exists (Reaction.summary).
    reactions: raw.reactions ?? null,
    responsesCount: raw.responses_count ?? 0,
    isImported: raw.commenter_imported ?? false,
    duplicateOfReviewId: raw.duplicate_of_review_id ?? null,
    addressedByRuleId: raw.addressed_by_rule_id ?? null,
    addressedByRuleName: raw.addressed_by_rule_name ?? null,
    adjudicatedAt: raw.adjudicated_at ?? null,
    ruleDisplayedName: raw.rule_displayed_name ?? null,
    commentableType: raw.commentable_type ?? null,
    ruleContent: raw.rule_content ?? null,
    respondingToReviewId: raw.responding_to_review_id ?? null,
    groupRuleDisplayedName: raw.group_rule_displayed_name ?? null,
    parentRuleDisplayedName: raw.parent_rule_displayed_name ?? null,
  };
}
