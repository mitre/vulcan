import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ReplyComposerMixin from "@/mixins/ReplyComposerMixin.vue";

function createHost(methodOverrides = {}) {
  const Host = {
    mixins: [ReplyComposerMixin],
    template: "<div />",
    methods: methodOverrides,
  };
  return mount(Host, {
    localVue,
    mocks: { $bvModal: { show: vi.fn() } },
  });
}

const replyPayload = {
  reviewId: 42,
  ruleId: 10,
  componentId: 8,
  ruleName: "CNTR-01-000001",
};

const sectionPayload = {
  ruleId: 10,
  componentId: 8,
  section: "check_content",
  ruleName: "CNTR-01-000001",
};

describe("ReplyComposerMixin", () => {
  // ── Initial state ──────────────────────────────────────────────────

  it("initializes composerState with all null fields and mode null", () => {
    const w = createHost();
    expect(w.vm.composerState).toEqual({
      mode: null,
      reviewId: null,
      ruleId: null,
      componentId: null,
      section: null,
      ruleName: null,
    });
  });

  it("composerActive is false initially", () => {
    const w = createHost();
    expect(w.vm.composerActive).toBe(false);
  });

  // ── openReplyComposer ──────────────────────────────────────────────

  it("sets mode to 'reply' with reviewId and rule context", async () => {
    const w = createHost();
    w.vm.openReplyComposer(replyPayload);
    await w.vm.$nextTick();
    expect(w.vm.composerState.mode).toBe("reply");
    expect(w.vm.composerState.reviewId).toBe(42);
    expect(w.vm.composerState.ruleId).toBe(10);
    expect(w.vm.composerState.componentId).toBe(8);
    expect(w.vm.composerState.ruleName).toBe("CNTR-01-000001");
    expect(w.vm.composerState.section).toBe(null);
  });

  it("shows the modal after openReplyComposer", async () => {
    const w = createHost();
    const showSpy = vi.spyOn(w.vm.$bvModal, "show");
    w.vm.openReplyComposer(replyPayload);
    await w.vm.$nextTick();
    await w.vm.$nextTick();
    expect(showSpy).toHaveBeenCalledWith("comment-composer-modal");
  });

  it("composerActive is true after openReplyComposer", async () => {
    const w = createHost();
    w.vm.openReplyComposer(replyPayload);
    await w.vm.$nextTick();
    expect(w.vm.composerActive).toBe(true);
  });

  // ── openSectionComposer ────────────────────────────────────────────

  it("sets mode to 'new-comment' with section and rule context", async () => {
    const w = createHost();
    w.vm.openSectionComposer(sectionPayload);
    await w.vm.$nextTick();
    expect(w.vm.composerState.mode).toBe("new-comment");
    expect(w.vm.composerState.section).toBe("check_content");
    expect(w.vm.composerState.ruleId).toBe(10);
    expect(w.vm.composerState.reviewId).toBe(null);
  });

  // ── openComponentComposer ──────────────────────────────────────────

  it("sets mode to 'component' with componentId only", async () => {
    const w = createHost();
    w.vm.openComponentComposer(8);
    await w.vm.$nextTick();
    expect(w.vm.composerState.mode).toBe("component");
    expect(w.vm.composerState.componentId).toBe(8);
    expect(w.vm.composerState.ruleId).toBe(null);
    expect(w.vm.composerState.reviewId).toBe(null);
  });

  // ── closeComposer ──────────────────────────────────────────────────

  it("resets all composerState fields to null", async () => {
    const w = createHost();
    w.vm.openReplyComposer(replyPayload);
    await w.vm.$nextTick();
    w.vm.closeComposer();
    expect(w.vm.composerState.mode).toBe(null);
    expect(w.vm.composerState.reviewId).toBe(null);
    expect(w.vm.composerActive).toBe(false);
  });

  // ── onComposerHidden (alias) ───────────────────────────────────────

  it("onComposerHidden clears state (alias for closeComposer)", async () => {
    const w = createHost();
    w.vm.openReplyComposer(replyPayload);
    await w.vm.$nextTick();
    w.vm.onComposerHidden();
    expect(w.vm.composerState.mode).toBe(null);
  });

  // ── onComposerPosted ───────────────────────────────────────────────

  it("clears state and calls afterComposerPosted with reviewId", async () => {
    const afterSpy = vi.fn();
    const w = createHost({ afterComposerPosted: afterSpy });
    w.vm.openReplyComposer(replyPayload);
    await w.vm.$nextTick();
    w.vm.onComposerPosted();
    expect(w.vm.composerState.mode).toBe(null);
    expect(afterSpy).toHaveBeenCalledWith(42);
  });

  it("calls afterComposerPosted with null for component mode", async () => {
    const afterSpy = vi.fn();
    const w = createHost({ afterComposerPosted: afterSpy });
    w.vm.openComponentComposer(8);
    await w.vm.$nextTick();
    w.vm.onComposerPosted();
    expect(afterSpy).toHaveBeenCalledWith(null);
  });

  it("calls afterComposerPosted with null when composer was never opened", () => {
    const afterSpy = vi.fn();
    const w = createHost({ afterComposerPosted: afterSpy });
    w.vm.onComposerPosted();
    expect(afterSpy).toHaveBeenCalledWith(null);
  });

  // ── composerProps computed ─────────────────────────────────────────

  it("maps composerState to CommentComposerModal props for reply mode", async () => {
    const w = createHost();
    w.vm.openReplyComposer(replyPayload);
    await w.vm.$nextTick();
    const props = w.vm.composerProps;
    expect(props.componentId).toBe(8);
    expect(props.ruleId).toBe(10);
    expect(props.ruleDisplayedName).toBe("CNTR-01-000001");
    expect(props.replyToReviewId).toBe(42);
    expect(props.initialSection).toBe(null);
  });

  it("maps composerState to props for new-comment mode", async () => {
    const w = createHost();
    w.vm.openSectionComposer(sectionPayload);
    await w.vm.$nextTick();
    const props = w.vm.composerProps;
    expect(props.ruleId).toBe(10);
    expect(props.initialSection).toBe("check_content");
    expect(props.replyToReviewId).toBe(null);
  });

  it("maps composerState to props for component mode", async () => {
    const w = createHost();
    w.vm.openComponentComposer(8);
    await w.vm.$nextTick();
    const props = w.vm.composerProps;
    expect(props.componentId).toBe(8);
    expect(props.ruleId).toBe(null);
    expect(props.replyToReviewId).toBe(null);
    expect(props.initialSection).toBe(null);
  });

  it("returns empty props when composer is closed", () => {
    const w = createHost();
    const props = w.vm.composerProps;
    expect(props.componentId).toBe(null);
    expect(props.ruleId).toBe(null);
    expect(props.replyToReviewId).toBe(null);
  });
});
