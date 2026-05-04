import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import axios from "axios";
import CommentDedupBanner from "@/components/components/CommentDedupBanner.vue";

vi.mock("axios");

const flushPromises = async (wrapper) => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  if (wrapper) await wrapper.vm.$nextTick();
};

const baseProps = { componentId: 8, ruleId: 2976 };

const sampleRows = [
  {
    id: 1,
    author_name: "John Doe",
    section: "check_content",
    comment: "Check text issue",
    created_at: "2026-04-27T10:00:00Z",
  },
  {
    id: 2,
    author_name: "Sarah K",
    section: "fixtext",
    comment: "Fix mention is wrong",
    created_at: "2026-04-26T10:00:00Z",
  },
  {
    id: 3,
    author_name: "Anon",
    section: null,
    comment: "General concern",
    created_at: "2026-04-25T10:00:00Z",
  },
];

/**
 * REQUIREMENTS:
 *
 * The dedup banner shows commenters PRIOR conversation on the rule so
 * they can avoid duplicating an existing comment. Behavior:
 *
 * 1. Always loads ALL rule-level comments — never filtered server-side
 *    by section. Section-scoped count is computed client-side (inSection)
 *    and surfaced in the header so commenters see "X total / Y on this
 *    section" at a glance.
 * 2. Each row carries its own SectionLabel badge so the commenter sees
 *    which section each prior comment targets.
 * 3. Each row has a [Reply] link that emits 'reply' with the row id —
 *    the parent (CommentComposerModal) switches into reply mode.
 * 4. Hidden when there are zero rule-level comments (nothing to dedup).
 */
describe("CommentDedupBanner", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const mountWith = async (sectionProp = null, rows = sampleRows) => {
    axios.get.mockResolvedValue({ data: { rows, pagination: { total: rows.length } } });
    const w = mount(CommentDedupBanner, {
      localVue,
      propsData: { ...baseProps, section: sectionProp },
    });
    await flushPromises(w);
    return w;
  };

  it("fetches ALL rule-level comments — no section param sent", async () => {
    await mountWith("check_content");
    const params = axios.get.mock.calls[0][1].params;
    expect(params.rule_id).toBe(2976);
    expect(params.section).toBeUndefined();
  });

  it("hides entirely when there are no comments on the rule", async () => {
    const w = await mountWith(null, []);
    expect(w.find("button").exists()).toBe(false);
  });

  it("shows total comment count in the header", async () => {
    const w = await mountWith();
    expect(w.text()).toContain("3 existing comments on this rule");
  });

  it("appends the section-scoped count to the header when section is selected", async () => {
    const w = await mountWith("check_content");
    // 1 of 3 rows is in check_content
    expect(w.text()).toContain("1 on Check");
  });

  it("does NOT append the section-scoped suffix when section is null (general)", async () => {
    const w = await mountWith(null);
    expect(w.text()).not.toMatch(/on \w+\)/);
  });

  it("renders a SectionLabel badge for each row that has a section", async () => {
    const w = await mountWith();
    // Expand the list so rows are visible
    await w.find("button").trigger("click");
    const labels = w.findAllComponents({ name: "SectionLabel" });
    // 2 rows have a section (check_content + fixtext); the null-section
    // row does NOT render a SectionLabel because v-if="row.section".
    expect(labels.length).toBe(2);
  });

  it("emits 'reply' with the row id when the [Reply] link is clicked", async () => {
    const w = await mountWith();
    // Expand so the list is in the DOM
    await w.find("button").trigger("click");
    const replyLinks = w.findAll("a");
    const firstReply = replyLinks.wrappers.find((a) => a.text() === "[Reply]");
    expect(firstReply).toBeDefined();
    await firstReply.trigger("click");
    expect(w.emitted("reply")).toBeTruthy();
    expect(w.emitted("reply")[0]).toEqual([1]);
  });

  it("does NOT re-fetch when only the section prop changes", async () => {
    const w = await mountWith("check_content");
    axios.get.mockClear();
    await w.setProps({ section: "fixtext" });
    await flushPromises(w);
    expect(axios.get).not.toHaveBeenCalled();
  });

  it("does re-fetch when ruleId changes (different rule = different conversation)", async () => {
    const w = await mountWith();
    axios.get.mockClear();
    await w.setProps({ ruleId: 9999 });
    await flushPromises(w);
    expect(axios.get).toHaveBeenCalled();
  });

  it("recomputes inSection when section prop changes (no refetch)", async () => {
    const w = await mountWith("check_content");
    expect(w.vm.inSection).toBe(1); // 1 row in check_content
    await w.setProps({ section: "fixtext" });
    expect(w.vm.inSection).toBe(1); // 1 row in fixtext
    await w.setProps({ section: null });
    expect(w.vm.inSection).toBe(0); // null section never matches
  });
});
