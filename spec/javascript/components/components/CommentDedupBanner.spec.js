import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { setActivePinia, createPinia } from "pinia";
import { localVue } from "@test/testHelper";
import CommentDedupBanner from "@/components/components/CommentDedupBanner.vue";
import { getComments } from "@/api/componentsApi";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: {} })),
    post: vi.fn(() => Promise.resolve({ data: {} })),
    put: vi.fn(() => Promise.resolve({ data: {} })),
    patch: vi.fn(() => Promise.resolve({ data: {} })),
    delete: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } },
  },
}));

vi.mock("@/api/componentsApi", () => ({
  getComments: vi.fn(() => Promise.resolve({ data: { rows: [], pagination: { total: 0 } } })),
}));

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
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  const mountWith = async (sectionProp = null, rows = sampleRows) => {
    getComments.mockResolvedValue({ data: { rows, pagination: { total: rows.length } } });
    const w = mount(CommentDedupBanner, {
      localVue,
      propsData: { ...baseProps, section: sectionProp },
    });
    await flushPromises(w);
    return w;
  };

  it("fetches ALL rule-level comments — no section param sent", async () => {
    await mountWith("check_content");
    const params = getComments.mock.calls[0][1];
    expect(params.rule_id).toBe(2976);
    expect(params.section).toBeUndefined();
  });

  it("hides entirely when there are no comments on the rule", async () => {
    const w = await mountWith(null, []);
    expect(w.find("button").exists()).toBe(false);
  });

  it("shows total comment count (replies included) in the header", async () => {
    // Server reports 3 top-level rows, 7 total comments (3 root + 4 replies).
    // A reply counts as a comment for display purposes.
    getComments.mockResolvedValue({
      data: {
        rows: sampleRows,
        pagination: { total: 3, total_comments: 7 },
      },
    });
    const w = mount(CommentDedupBanner, {
      localVue,
      propsData: { ...baseProps, section: null },
    });
    await flushPromises(w);
    expect(w.text()).toContain("7 existing comments on this rule");
  });

  it("falls back to top-level total when total_comments is absent", async () => {
    // Older/cached payloads without total_comments still render correctly.
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

  it("emits 'reply' with the row id when CommentThread emits reply", async () => {
    const w = await mountWith();
    // Expand so the per-row CommentThreads are in the DOM
    await w.find("button").trigger("click");
    const threads = w.findAllComponents({ name: "CommentThread" });
    expect(threads.length).toBe(3);
    threads.at(0).vm.$emit("reply", 1);
    expect(w.emitted("reply")).toBeTruthy();
    expect(w.emitted("reply")[0]).toEqual([1]);
  });

  it("does NOT re-fetch when only the section prop changes", async () => {
    const w = await mountWith("check_content");
    getComments.mockClear();
    await w.setProps({ section: "fixtext" });
    await flushPromises(w);
    expect(getComments).not.toHaveBeenCalled();
  });

  it("does re-fetch when ruleId changes (different rule = different conversation)", async () => {
    const w = await mountWith();
    getComments.mockClear();
    await w.setProps({ ruleId: 9999 });
    await flushPromises(w);
    expect(getComments).toHaveBeenCalled();
  });

  describe("section-matching visual highlight", () => {
    it("dims comments that do not match the selected section", async () => {
      const w = await mountWith("check_content");
      await w.find("button").trigger("click");
      const items = w.findAll("li");
      expect(items.at(0).classes()).not.toContain("dedup-dimmed"); // check_content matches
      expect(items.at(1).classes()).toContain("dedup-dimmed"); // fixtext does not match
      expect(items.at(2).classes()).toContain("dedup-dimmed"); // null does not match
    });

    it("does not dim any comments when no section is selected", async () => {
      const w = await mountWith(null);
      await w.find("button").trigger("click");
      const dimmed = w.findAll(".dedup-dimmed");
      expect(dimmed.length).toBe(0);
    });

    it("updates dimming when section prop changes", async () => {
      const w = await mountWith("check_content");
      await w.find("button").trigger("click");
      expect(w.findAll(".dedup-dimmed").length).toBe(2); // fixtext + null dimmed

      await w.setProps({ section: "fixtext" });
      expect(w.findAll(".dedup-dimmed").length).toBe(2); // check_content + null dimmed

      await w.setProps({ section: null });
      expect(w.findAll(".dedup-dimmed").length).toBe(0); // nothing dimmed
    });
  });

  it("recomputes inSection when section prop changes (no refetch)", async () => {
    const w = await mountWith("check_content");
    expect(w.vm.inSection).toBe(1); // 1 row in check_content
    await w.setProps({ section: "fixtext" });
    expect(w.vm.inSection).toBe(1); // 1 row in fixtext
    await w.setProps({ section: null });
    expect(w.vm.inSection).toBe(0); // null section never matches
  });

  // ── v2-05f.62.5: CommentItem migration ──────────────────────────────

  it("renders CommentItem for each comment row", async () => {
    const w = await mountWith("check_content");
    w.vm.expanded = true;
    await w.vm.$nextTick();
    const items = w.findAllComponents({ name: "CommentItem" });
    expect(items.length).toBe(3);
  });

  it("passes normalized comment data to CommentItem", async () => {
    const w = await mountWith("check_content");
    w.vm.expanded = true;
    await w.vm.$nextTick();
    const first = w.findComponent({ name: "CommentItem" });
    expect(first.props("comment").id).toBe(1);
    expect(first.props("comment").authorName).toBe("John Doe");
  });
});
