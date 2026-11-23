/**
 * A CommentThread instance is reused across comments (the triage split view
 * renders one unkeyed thread for whichever comment is active), so switching
 * `parentReviewId` has to leave the component in a state that matches the NEW
 * parent.
 *
 * REQUIREMENTS:
 *
 * R1 — A thread that is open when the parent switches must end up showing the
 *      new parent's replies. Dropping the old replies is not enough: an open
 *      thread that renders nothing is just as wrong as one that renders the
 *      previous comment's replies.
 *
 * R2 — A thread that is closed when the parent switches must not request
 *      anything. Replies load when the user asks to see them.
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { setActivePinia, createPinia } from "pinia";
import { localVue } from "@test/testHelper";
import CommentThread from "@/components/shared/CommentThread.vue";
import { getReviewResponses } from "@/api/reviewsApi";

vi.mock("@/api/baseApi", async () => (await import("@test/support/apiMocks")).baseApi());
vi.mock("@/api/componentsApi", async () =>
  (await import("@test/support/apiMocks")).componentsApi(),
);
vi.mock("@/api/reviewsApi", async () => (await import("@test/support/apiMocks")).reviewsApi());

// One reply per parent, named after its parent so the rendered text says
// which thread is on screen.
function replyFor(parentReviewId) {
  return {
    data: {
      rows: [
        {
          id: parentReviewId * 10,
          comment: `reply to ${parentReviewId}`,
          commenter_display_name: "Replier",
          commenter_imported: false,
          created_at: "2026-05-04T00:00:00Z",
        },
      ],
    },
  };
}

const settle = () => new Promise((r) => setTimeout(r, 0));

describe("CommentThread — switching parents on a live instance", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    getReviewResponses.mockReset();
    getReviewResponses.mockImplementation((id) => Promise.resolve(replyFor(id)));
  });

  // R1
  it("reloads and renders the new parent's replies when it stays open", async () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1, initiallyExpanded: true },
    });
    await settle();
    await w.find("button[aria-controls]").trigger("click");
    await settle();
    expect(w.text()).toContain("reply to 1");

    // initiallyExpanded keeps the thread open across the switch.
    await w.setProps({ parentReviewId: 2 });
    await settle();

    expect(w.text()).toContain("reply to 2");
    expect(w.text()).not.toContain("reply to 1");
  });

  // R2
  it("requests nothing when it is closed as the parent switches", async () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });
    await settle();

    await w.setProps({ parentReviewId: 2 });
    await settle();

    expect(getReviewResponses).not.toHaveBeenCalled();
  });
});
