import { describe, it, expect, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import CommentsByRule from "@/components/components/CommentsByRule.vue";

const mockRows = [
  {
    id: 1,
    rule_id: 100,
    rule_displayed_name: "CNTR-01-000001",
    section: "check_content",
    author_name: "Demo Viewer",
    comment: "Check needs CLI example",
    created_at: "2026-05-19T14:08:17.653Z",
    triage_status: "pending",
    responses_count: 1,
    reactions: { up: 1, down: 0, mine: null },
  },
  {
    id: 2,
    rule_id: 100,
    rule_displayed_name: "CNTR-01-000001",
    section: "check_content",
    author_name: "Demo Reviewer",
    comment: "Agree — also clarify trusted sources",
    created_at: "2026-05-19T14:08:17.683Z",
    triage_status: "concur",
    responses_count: 0,
    reactions: { up: 0, down: 0, mine: null },
  },
  {
    id: 6,
    rule_id: 100,
    rule_displayed_name: "CNTR-01-000001",
    section: "fixtext",
    author_name: "Demo Viewer",
    comment: "Fix text too broad",
    created_at: "2026-05-19T14:08:17.736Z",
    triage_status: "pending",
    responses_count: 0,
    reactions: { up: 0, down: 0, mine: null },
  },
  {
    id: 9,
    rule_id: 200,
    rule_displayed_name: "CNTR-01-000002",
    section: "fixtext",
    author_name: "Demo Viewer",
    comment: "Clarify etcd vs external",
    created_at: "2026-05-19T14:08:17.774Z",
    triage_status: "pending",
    responses_count: 0,
    reactions: { up: 0, down: 0, mine: null },
  },
];

describe("CommentsByRule", () => {
  let wrapper;

  beforeEach(() => {
    wrapper = mount(CommentsByRule, {
      propsData: { rows: mockRows },
    });
  });

  it("groups comments by rule_displayed_name", () => {
    const ruleHeaders = wrapper.findAll("[data-testid='rule-group-header']");
    expect(ruleHeaders.length).toBe(2);
    expect(ruleHeaders.at(0).text()).toContain("CNTR-01-000001");
    expect(ruleHeaders.at(1).text()).toContain("CNTR-01-000002");
  });

  it("shows comment count per rule in header", () => {
    const headers = wrapper.findAll("[data-testid='rule-group-header']");
    expect(headers.at(0).text()).toContain("3");
    expect(headers.at(1).text()).toContain("1");
  });

  it("defaults to collapsed rule groups", () => {
    const content = wrapper.findAll("[data-testid='rule-group-content']");
    content.wrappers.forEach((w) => {
      expect(w.isVisible()).toBe(false);
    });
  });

  it("groups comments by section within each rule when expanded", async () => {
    await wrapper.find("[data-testid='rule-group-header']").trigger("click");
    const firstGroup = wrapper.find("[data-testid='rule-group-content']");
    const sectionHeaders = firstGroup.findAll("[data-testid='section-group-header']");
    expect(sectionHeaders.length).toBe(2);
  });

  it("renders each comment with author, text, and triage status when expanded", async () => {
    await wrapper.find("[data-testid='rule-group-header']").trigger("click");
    const firstGroup = wrapper.find("[data-testid='rule-group-content']");
    const comments = firstGroup.findAll("[data-testid='comment-entry']");
    expect(comments.length).toBe(3);
    expect(comments.at(0).text()).toContain("Demo Viewer");
    expect(comments.at(0).text()).toContain("Check needs CLI example");
  });

  it("renders empty state when no rows", () => {
    const empty = mount(CommentsByRule, { propsData: { rows: [] } });
    expect(empty.text()).toContain("No comments");
  });

  it("expands rule group on click, collapses on second click", async () => {
    const header = wrapper.find("[data-testid='rule-group-header']");
    const content = wrapper.find("[data-testid='rule-group-content']");

    expect(content.isVisible()).toBe(false);

    await header.trigger("click");
    expect(content.isVisible()).toBe(true);

    await header.trigger("click");
    expect(content.isVisible()).toBe(false);
  });
});
