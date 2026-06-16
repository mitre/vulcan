import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CommentItem from "@/components/shared/CommentItem.vue";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
    defaults: { headers: { common: {} } },
  },
}));

const baseComment = {
  id: 142,
  authorName: "John Doe",
  authorEmail: "john@example.com",
  text: "Check text is vague about TLS verification.",
  section: "check_content",
  triageStatus: "pending",
  createdAt: "2026-04-27T10:00:00Z",
  reactions: { up: 1, down: 0, mine: null },
  responsesCount: 2,
  isImported: false,
};

describe("CommentItem", () => {
  describe("default rendering", () => {
    it("renders UserBadge in the aside slot with author name/email", () => {
      const w = mount(CommentItem, {
        localVue,
        propsData: { comment: baseComment },
      });
      const badge = w.findComponent({ name: "UserBadge" });
      expect(badge.exists()).toBe(true);
      expect(badge.props("name")).toBe("John Doe");
      expect(badge.props("email")).toBe("john@example.com");
    });

    it("renders CommentAuthorLine in the default header slot", () => {
      const w = mount(CommentItem, {
        localVue,
        propsData: { comment: baseComment },
      });
      const authorLine = w.findComponent({ name: "CommentAuthorLine" });
      expect(authorLine.exists()).toBe(true);
    });

    it("renders SectionLabel when section is present", () => {
      const w = mount(CommentItem, {
        localVue,
        propsData: { comment: baseComment },
      });
      const sl = w.findComponent({ name: "SectionLabel" });
      expect(sl.exists()).toBe(true);
      expect(sl.props("section")).toBe("check_content");
    });

    it("does not render SectionLabel when section is null", () => {
      const w = mount(CommentItem, {
        localVue,
        propsData: { comment: { ...baseComment, section: null } },
      });
      const sl = w.findComponent({ name: "SectionLabel" });
      expect(sl.exists()).toBe(false);
    });

    it("renders TriageStatusBadge in the default status slot", () => {
      const w = mount(CommentItem, {
        localVue,
        propsData: { comment: baseComment },
      });
      const tsb = w.findComponent({ name: "TriageStatusBadge" });
      expect(tsb.exists()).toBe(true);
      expect(tsb.props("status")).toBe("pending");
    });

    it("renders CommentBody in the default body slot", () => {
      const w = mount(CommentItem, {
        localVue,
        propsData: { comment: baseComment },
      });
      const body = w.findComponent({ name: "CommentBody" });
      expect(body.exists()).toBe(true);
      expect(body.props("text")).toBe("Check text is vague about TLS verification.");
    });

    it("renders CommentActions in the default actions slot", () => {
      const w = mount(CommentItem, {
        localVue,
        propsData: { comment: baseComment },
      });
      const actions = w.findComponent({ name: "CommentActions" });
      expect(actions.exists()).toBe(true);
      expect(actions.props("reviewId")).toBe(142);
      expect(actions.props("responsesCount")).toBe(2);
    });

    it("applies triage background class to wrapper for non-pending status", () => {
      const w = mount(CommentItem, {
        localVue,
        propsData: { comment: { ...baseComment, triageStatus: "concur" } },
      });
      expect(w.classes()).toContain("triage-bg--concur");
    });

    it("does not apply triage-bg class for pending status", () => {
      const w = mount(CommentItem, {
        localVue,
        propsData: { comment: baseComment },
      });
      expect(w.classes().join(" ")).not.toMatch(/triage-bg--/);
    });
  });

  describe("slot overrides", () => {
    it("allows overriding the header slot", () => {
      const w = mount(CommentItem, {
        localVue,
        propsData: { comment: baseComment },
        scopedSlots: {
          header: '<div class="custom-header">{{ props.comment.authorName }}</div>',
        },
      });
      expect(w.find(".custom-header").exists()).toBe(true);
      expect(w.find(".custom-header").text()).toBe("John Doe");
      expect(w.findComponent({ name: "CommentAuthorLine" }).exists()).toBe(false);
    });

    it("allows overriding the body slot", () => {
      const w = mount(CommentItem, {
        localVue,
        propsData: { comment: baseComment },
        scopedSlots: {
          body: "<blockquote>{{ props.comment.text }}</blockquote>",
        },
      });
      expect(w.find("blockquote").exists()).toBe(true);
      expect(w.findComponent({ name: "CommentBody" }).exists()).toBe(false);
    });

    it("renders the extra slot when provided", () => {
      const w = mount(CommentItem, {
        localVue,
        propsData: { comment: baseComment },
        scopedSlots: {
          extra: '<div class="triage-form">Triage goes here</div>',
        },
      });
      expect(w.find(".triage-form").exists()).toBe(true);
      expect(w.find(".triage-form").text()).toBe("Triage goes here");
    });
  });

  describe("events", () => {
    it("forwards toggle-reaction from CommentActions", () => {
      const w = mount(CommentItem, {
        localVue,
        propsData: { comment: baseComment },
      });
      const actions = w.findComponent({ name: "CommentActions" });
      actions.vm.$emit("toggle-reaction", "up");
      expect(w.emitted("toggle-reaction")).toBeTruthy();
      expect(w.emitted("toggle-reaction")[0]).toEqual(["up"]);
    });

    it("forwards reply from CommentActions", () => {
      const w = mount(CommentItem, {
        localVue,
        propsData: { comment: baseComment },
      });
      const actions = w.findComponent({ name: "CommentActions" });
      actions.vm.$emit("reply", 142);
      expect(w.emitted("reply")).toBeTruthy();
      expect(w.emitted("reply")[0]).toEqual([142]);
    });
  });
});
