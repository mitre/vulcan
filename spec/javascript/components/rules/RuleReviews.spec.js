import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleReviews from "@/components/rules/RuleReviews.vue";

/**
 * REQUIREMENTS:
 * The per-rule review thread must reflect the public-comment-review
 * lifecycle introduced by PR #717:
 *   - Each top-level comment shows the section it targets (SectionLabel).
 *   - Each top-level comment shows its triage status (TriageStatusBadge).
 *   - Replies (reviews with responding_to_review_id) are nested under
 *     their parent comment.
 *   - A section filter dropdown limits which top-level comments render.
 * The pre-existing show-older / show-fewer pagination must keep working.
 */
describe("RuleReviews", () => {
  const reviewsWithLifecycle = [
    {
      id: 142,
      action: "comment",
      comment: "Check text issue",
      section: "check_content",
      name: "John Doe",
      created_at: "2026-04-27T10:00:00Z",
      triage_status: "pending",
      responding_to_review_id: null,
      adjudicated_at: null,
    },
    {
      id: 143,
      action: "comment",
      comment: "Will adopt the spirit",
      section: "check_content",
      name: "Aaron Lippold",
      created_at: "2026-04-28T10:00:00Z",
      triage_status: "pending",
      responding_to_review_id: 142,
      adjudicated_at: null,
    },
    {
      id: 144,
      action: "comment",
      comment: "Severity too low",
      section: "severity",
      name: "Sarah K",
      created_at: "2026-04-26T10:00:00Z",
      triage_status: "non_concur",
      responding_to_review_id: null,
      adjudicated_at: null,
    },
  ];

  const mountWith = (reviews) =>
    mount(RuleReviews, {
      localVue,
      propsData: { rule: { reviews } },
    });

  describe("section + triage badges", () => {
    it("renders section badges on top-level comments", () => {
      const w = mountWith(reviewsWithLifecycle);
      expect(w.text()).toContain("Check");
      expect(w.text()).toContain("Severity");
    });

    it("renders TriageStatusBadge for each top-level comment only", () => {
      const w = mountWith(reviewsWithLifecycle);
      const badges = w.findAllComponents({ name: "TriageStatusBadge" });
      expect(badges.length).toBe(2);
    });
  });

  describe("response nesting", () => {
    it("renders responses under their parent (responding_to_review_id)", () => {
      const w = mountWith(reviewsWithLifecycle);
      const html = w.html();
      const johnIdx = html.indexOf("John Doe");
      const aaronIdx = html.indexOf("Aaron Lippold");
      expect(johnIdx).toBeGreaterThan(-1);
      expect(aaronIdx).toBeGreaterThan(-1);
      // Reply must appear after the parent it responds to
      expect(johnIdx).toBeLessThan(aaronIdx);
    });

    it("does not double-count replies as top-level comments", () => {
      const w = mountWith(reviewsWithLifecycle);
      // There are 3 reviews total but only 2 top-level — so only 2 status
      // badges (verified above), and exactly one block contains the
      // 'responding to' indicator
      expect(w.html().match(/responding to/g)?.length || 0).toBe(1);
    });
  });

  describe("section filter", () => {
    it("filters thread by section via dropdown", async () => {
      const w = mountWith(reviewsWithLifecycle);
      w.vm.sectionFilter = "severity";
      await w.vm.$nextTick();
      expect(w.text()).not.toContain("Check text issue");
      expect(w.text()).toContain("Severity too low");
    });

    it("shows both sections by default (filter == 'all')", () => {
      const w = mountWith(reviewsWithLifecycle);
      expect(w.text()).toContain("Check text issue");
      expect(w.text()).toContain("Severity too low");
    });

    it("shows a friendly empty message when filter has no matches", async () => {
      const w = mountWith(reviewsWithLifecycle);
      w.vm.sectionFilter = "fixtext";
      await w.vm.$nextTick();
      expect(w.text()).toContain("No comments match this filter");
    });
  });

  describe("backwards compatibility — pre-existing behavior preserved", () => {
    it("renders empty-thread message when there are no reviews", () => {
      const w = mountWith([]);
      expect(w.text()).toContain("No reviews or comments yet");
    });

    it("starts with numShownReviews=2 (pre-existing pagination)", () => {
      const w = mountWith(reviewsWithLifecycle);
      expect(w.vm.numShownReviews).toBe(2);
    });
  });
});
