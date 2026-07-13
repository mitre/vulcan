import { describe, it, expect } from "vitest";
import { normalizeComment } from "@/utils/normalizeComment";

describe("normalizeComment", () => {
  const raw = {
    id: 7,
    rule_id: 100,
    author_name: "Demo Viewer",
    commenter_email: "viewer@example.org",
    comment: "Check needs CLI example",
    section: "check_content",
    triage_status: "concur",
    created_at: "2026-05-19T14:08:17.653Z",
    reactions: { up: 1, down: 0, mine: null },
    responses_count: 2,
    commenter_imported: false,
    duplicate_of_review_id: null,
    addressed_by_rule_id: null,
    addressed_by_rule_name: null,
    adjudicated_at: "2026-05-20T10:00:00Z",
    rule_displayed_name: "CNTR-01-000001",
    commentable_type: "BaseRule",
    rule_content: null,
    responding_to_review_id: null,
    group_rule_displayed_name: "CNTR-01-000001",
    parent_rule_displayed_name: null,
  };

  it("maps wire fields to camelCase", () => {
    const n = normalizeComment(raw);
    expect(n.ruleId).toBe(100);
    expect(n.authorName).toBe("Demo Viewer");
    expect(n.authorEmail).toBe("viewer@example.org");
    expect(n.text).toBe("Check needs CLI example");
    expect(n.triageStatus).toBe("concur");
    expect(n.createdAt).toBe("2026-05-19T14:08:17.653Z");
    expect(n.responsesCount).toBe(2);
    expect(n.adjudicatedAt).toBe("2026-05-20T10:00:00Z");
    expect(n.ruleDisplayedName).toBe("CNTR-01-000001");
  });

  it("keeps the original wire fields alongside (spread)", () => {
    const n = normalizeComment(raw);
    expect(n.author_name).toBe("Demo Viewer");
    expect(n.triage_status).toBe("concur");
  });

  it("falls back authorName to commenter_display_name", () => {
    const n = normalizeComment({ ...raw, author_name: null, commenter_display_name: "Imported X" });
    expect(n.authorName).toBe("Imported X");
  });

  it("normalizes absent reactions to null, not an empty object", () => {
    const n = normalizeComment({ ...raw, reactions: undefined });
    expect(n.reactions).toBeNull();
  });

  it("normalizes an absent rule_id to null like every other field", () => {
    const n = normalizeComment({ ...raw, rule_id: undefined });
    expect(n.ruleId).toBeNull();
  });

  it("is idempotent — normalizing a normalized row changes nothing", () => {
    const once = normalizeComment(raw);
    const twice = normalizeComment(once);
    expect(twice).toEqual(once);
  });
});
