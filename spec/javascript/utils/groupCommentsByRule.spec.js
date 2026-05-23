import { describe, it, expect } from "vitest";
import { groupCommentsByRule } from "@/utils/groupCommentsByRule";

const comments = [
  { id: 1, rule_id: 10, rule_displayed_name: "CNTR-01-000001", group_rule_displayed_name: "CNTR-01-000001", section: "check_content", triage_status: "pending" },
  { id: 2, rule_id: 10, rule_displayed_name: "CNTR-01-000001", group_rule_displayed_name: "CNTR-01-000001", section: "fixtext", triage_status: "concur" },
  { id: 3, rule_id: 11, rule_displayed_name: "CNTR-01-000002", group_rule_displayed_name: "CNTR-01-000002", section: null, triage_status: "pending" },
  { id: 4, rule_id: null, rule_displayed_name: "(component)", group_rule_displayed_name: null, commentable_type: "Component", section: null, triage_status: "pending" },
];

describe("groupCommentsByRule", () => {
  it("groups comments by group_rule_displayed_name", () => {
    const groups = groupCommentsByRule(comments);
    expect(groups.length).toBe(3);
  });

  it("sorts component group first, then alphabetically", () => {
    const groups = groupCommentsByRule(comments);
    expect(groups[0].key).toBe("(component)");
    expect(groups[1].key).toBe("CNTR-01-000001");
    expect(groups[2].key).toBe("CNTR-01-000002");
  });

  it("accumulates comments in each group", () => {
    const groups = groupCommentsByRule(comments);
    const rule1 = groups.find((g) => g.key === "CNTR-01-000001");
    expect(rule1.comments.length).toBe(2);
    expect(rule1.comments[0].id).toBe(1);
  });

  it("calculates pendingCount per group", () => {
    const groups = groupCommentsByRule(comments);
    const rule1 = groups.find((g) => g.key === "CNTR-01-000001");
    expect(rule1.pendingCount).toBe(1);
    const comp = groups.find((g) => g.key === "(component)");
    expect(comp.pendingCount).toBe(1);
  });

  it("uses numeric locale-aware sorting", () => {
    const items = [
      { id: 1, rule_displayed_name: "CNTR-01-000020", group_rule_displayed_name: "CNTR-01-000020", triage_status: "pending" },
      { id: 2, rule_displayed_name: "CNTR-01-000002", group_rule_displayed_name: "CNTR-01-000002", triage_status: "pending" },
    ];
    const groups = groupCommentsByRule(items);
    expect(groups[0].key).toBe("CNTR-01-000002");
    expect(groups[1].key).toBe("CNTR-01-000020");
  });

  it("falls back to rule_displayed_name when group_rule_displayed_name is null", () => {
    const items = [
      { id: 1, rule_displayed_name: "TEST-001", group_rule_displayed_name: null, triage_status: "pending" },
    ];
    const groups = groupCommentsByRule(items);
    expect(groups[0].key).toBe("TEST-001");
  });
});
