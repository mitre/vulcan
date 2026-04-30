import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import axios from "axios";
import CanonicalCommentPicker from "@/components/components/CanonicalCommentPicker.vue";

vi.mock("axios");

// REQUIREMENT (PR #717 Task 24): the canonical comment picker is the
// search/select widget shown when a triager marks a comment as duplicate.
// Scoped to the same component as the comment being triaged. Server enforces
// the same-component constraint via duplicate_of_must_be_same_component;
// picker also excludes already-duplicate rows + the self row as defense in depth.
describe("CanonicalCommentPicker", () => {
  const flushAll = async (w) => {
    // micro tick + axios resolve + next paint
    await new Promise((r) => setTimeout(r, 0));
    await w.vm.$nextTick();
    await new Promise((r) => setTimeout(r, 0));
    await w.vm.$nextTick();
  };

  beforeEach(() => {
    vi.clearAllMocks();
    axios.get.mockResolvedValue({
      data: {
        rows: [
          {
            id: 99,
            rule_id: 7,
            rule_displayed_name: "CRI-O-000050",
            author_name: "Sarah K",
            comment: "TLS 1.2 EOL by 2025",
            section: "vuln_discussion",
            triage_status: "pending",
            created_at: "2026-04-26T10:00:00Z",
          },
        ],
        pagination: { total: 1 },
      },
    });
  });

  it("fetches comments scoped to the same component on mount", async () => {
    const w = mount(CanonicalCommentPicker, {
      localVue,
      propsData: { componentId: 8, excludeReviewId: 50 },
    });
    await flushAll(w);
    expect(axios.get).toHaveBeenCalledWith(
      "/components/8/comments",
      expect.objectContaining({
        params: expect.objectContaining({ triage_status: "all" }),
      }),
    );
  });

  it("excludes the review being marked from the candidate list", async () => {
    axios.get.mockResolvedValueOnce({
      data: {
        rows: [
          {
            id: 50,
            rule_id: 7,
            rule_displayed_name: "CRI-O-000050",
            author_name: "Self",
            comment: "This is the duplicate itself",
            section: null,
            triage_status: "pending",
            created_at: "2026-04-25T10:00:00Z",
          },
          {
            id: 99,
            rule_id: 7,
            rule_displayed_name: "CRI-O-000050",
            author_name: "Sarah K",
            comment: "TLS 1.2 EOL",
            section: "vuln_discussion",
            triage_status: "pending",
            created_at: "2026-04-26T10:00:00Z",
          },
        ],
        pagination: { total: 2 },
      },
    });
    const w = mount(CanonicalCommentPicker, {
      localVue,
      propsData: { componentId: 8, excludeReviewId: 50 },
    });
    await flushAll(w);
    expect(w.text()).not.toContain("This is the duplicate itself");
    expect(w.text()).toContain("TLS 1.2 EOL");
  });

  it("excludes rows that are themselves duplicates (no chained)", async () => {
    axios.get.mockResolvedValueOnce({
      data: {
        rows: [
          {
            id: 99,
            triage_status: "duplicate",
            duplicate_of_review_id: 60,
            comment: "already a dup",
            rule_displayed_name: "X",
            author_name: "A",
            created_at: "2026-04-26T10:00:00Z",
          },
          {
            id: 100,
            triage_status: "pending",
            comment: "fresh canonical",
            rule_displayed_name: "Y",
            author_name: "B",
            created_at: "2026-04-27T10:00:00Z",
          },
        ],
        pagination: { total: 2 },
      },
    });
    const w = mount(CanonicalCommentPicker, {
      localVue,
      propsData: { componentId: 8, excludeReviewId: 50 },
    });
    await flushAll(w);
    expect(w.text()).not.toContain("already a dup");
    expect(w.text()).toContain("fresh canonical");
  });

  it("emits 'selected' with the review id when a candidate is clicked", async () => {
    const w = mount(CanonicalCommentPicker, {
      localVue,
      propsData: { componentId: 8, excludeReviewId: 50 },
    });
    await flushAll(w);
    await w.find('[data-test="canonical-candidate-99"]').trigger("click");
    expect(w.emitted("selected")[0]).toEqual([99]);
  });

  it("highlights the currently-selected candidate", async () => {
    const w = mount(CanonicalCommentPicker, {
      localVue,
      propsData: { componentId: 8, excludeReviewId: 50, selectedReviewId: 99 },
    });
    await flushAll(w);
    const selected = w.find('[data-test="canonical-candidate-99"]');
    expect(selected.classes()).toContain("border-primary");
  });

  it("widens client-side filter to match author name + rule name", async () => {
    axios.get.mockResolvedValue({
      data: {
        rows: [
          {
            id: 99,
            comment: "x",
            author_name: "Sarah K",
            rule_displayed_name: "CNTR-01-000001",
            triage_status: "pending",
            created_at: "2026-04-26T10:00:00Z",
          },
          {
            id: 100,
            comment: "y",
            author_name: "Bob L",
            rule_displayed_name: "CNTR-01-000002",
            triage_status: "pending",
            created_at: "2026-04-27T10:00:00Z",
          },
        ],
        pagination: { total: 2 },
      },
    });
    const w = mount(CanonicalCommentPicker, {
      localVue,
      propsData: { componentId: 8, excludeReviewId: 50 },
    });
    await flushAll(w);
    w.vm.query = "Sarah";
    await flushAll(w);
    expect(w.text()).toContain("Sarah K");
    expect(w.text()).not.toContain("Bob L");
  });
});
