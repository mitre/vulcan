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
    expect(comments.at(0).text()).toContain("DV");
    expect(comments.at(0).text()).toContain("Check needs CLI example");
  });

  it("renders empty state when no rows", () => {
    const empty = mount(CommentsByRule, { propsData: { rows: [] } });
    expect(empty.text()).toContain("No comments");
  });

  // ── Background tint by triage status ───────────────────────────────

  it("applies triage-bg--concur class to accepted comments", () => {
    const rows = [
      {
        id: 1,
        rule_id: 100,
        rule_displayed_name: "R1",
        section: "check_content",
        author_name: "A",
        comment: "Good",
        created_at: "2026-01-01",
        triage_status: "concur",
        responses_count: 0,
        reactions: { up: 0, down: 0, mine: null },
      },
    ];
    const w = mount(CommentsByRule, { propsData: { rows } });
    w.vm.toggleRule("R1");
    expect(w.find("[data-testid='comment-entry'].triage-bg--concur").exists()).toBe(true);
  });

  it("applies triage-bg--non_concur class to declined comments", () => {
    const rows = [
      {
        id: 1,
        rule_id: 100,
        rule_displayed_name: "R1",
        section: "check_content",
        author_name: "A",
        comment: "Bad",
        created_at: "2026-01-01",
        triage_status: "non_concur",
        responses_count: 0,
        reactions: { up: 0, down: 0, mine: null },
      },
    ];
    const w = mount(CommentsByRule, { propsData: { rows } });
    w.vm.toggleRule("R1");
    expect(w.find("[data-testid='comment-entry'].triage-bg--non_concur").exists()).toBe(true);
  });

  it("does not apply triage-bg class to pending comments", () => {
    const allPending = [
      {
        id: 1,
        rule_id: 100,
        rule_displayed_name: "R1",
        section: "check_content",
        author_name: "A",
        comment: "C1",
        created_at: "2026-01-01",
        triage_status: "pending",
        responses_count: 0,
        reactions: { up: 0, down: 0, mine: null },
      },
    ];
    const w = mount(CommentsByRule, { propsData: { rows: allPending } });
    w.vm.toggleRule("R1");
    const entries = w.findAll("[data-testid='comment-entry']");
    entries.wrappers.forEach((entry) => {
      expect(entry.classes().some((c) => c.startsWith("triage-bg--"))).toBe(false);
    });
  });

  // ── Pending/total split in header ─────────────────────────────────

  it("shows pending/total split when mixed statuses present", () => {
    const rows = [
      {
        id: 1,
        rule_id: 100,
        rule_displayed_name: "R1",
        section: "check_content",
        author_name: "A",
        comment: "C1",
        created_at: "2026-01-01",
        triage_status: "pending",
        responses_count: 0,
        reactions: { up: 0, down: 0, mine: null },
      },
      {
        id: 2,
        rule_id: 100,
        rule_displayed_name: "R1",
        section: "check_content",
        author_name: "B",
        comment: "C2",
        created_at: "2026-01-01",
        triage_status: "concur",
        responses_count: 0,
        reactions: { up: 0, down: 0, mine: null },
      },
    ];
    const w = mount(CommentsByRule, { propsData: { rows } });
    const header = w.find("[data-testid='rule-group-header']");
    expect(header.text()).toContain("1 pending");
    expect(header.text()).toContain("2 total");
  });

  it("shows pending/total even when all comments are pending (consistent format)", () => {
    const allPending = [
      {
        id: 1,
        rule_id: 100,
        rule_displayed_name: "R1",
        section: "check_content",
        author_name: "A",
        comment: "C1",
        created_at: "2026-01-01",
        triage_status: "pending",
        responses_count: 0,
        reactions: { up: 0, down: 0, mine: null },
      },
      {
        id: 2,
        rule_id: 100,
        rule_displayed_name: "R1",
        section: "fixtext",
        author_name: "B",
        comment: "C2",
        created_at: "2026-01-01",
        triage_status: "pending",
        responses_count: 0,
        reactions: { up: 0, down: 0, mine: null },
      },
    ];
    const w = mount(CommentsByRule, { propsData: { rows: allPending } });
    const header = w.find("[data-testid='rule-group-header']");
    expect(header.text()).toContain("2 pending");
    expect(header.text()).toContain("2 total");
  });

  // ── Expand all / collapse all ──────────────────────────────────────

  it("expands all groups when allExpanded prop becomes true", async () => {
    const w = mount(CommentsByRule, { propsData: { rows: mockRows, allExpanded: false } });
    expect(w.find("[data-testid='rule-group-content']").isVisible()).toBe(false);

    await w.setProps({ allExpanded: true });

    const contents = w.findAll("[data-testid='rule-group-content']");
    contents.wrappers.forEach((c) => {
      expect(c.isVisible()).toBe(true);
    });
  });

  it("collapses all groups when allExpanded prop becomes false", async () => {
    const w = mount(CommentsByRule, { propsData: { rows: mockRows, allExpanded: true } });
    await w.setProps({ allExpanded: false });

    const contents = w.findAll("[data-testid='rule-group-content']");
    contents.wrappers.forEach((c) => {
      expect(c.isVisible()).toBe(false);
    });
  });

  // ── Collapse/expand ───────────────────────────────────────────────

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
