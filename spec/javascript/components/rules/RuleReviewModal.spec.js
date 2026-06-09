import { describe, it, expect, afterEach, vi, beforeEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleReviewModal from "@/components/rules/RuleReviewModal.vue";

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

vi.mock("@/api/reviewsApi", () => ({
  createRuleReview: vi.fn(() => Promise.resolve({ data: {} })),
}));

describe("RuleReviewModal", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return shallowMount(RuleReviewModal, {
      localVue,
      propsData: {
        rule: { id: 1, component_id: 10, status: "Not Yet Determined", locked: false, review_requestor_id: null },
        effectivePermissions: "admin",
        currentUserId: 1,
        ...props,
      },
      stubs: { BModal: true, BFormGroup: true, BFormSelect: true, BFormTextarea: true, BButton: true },
      // No $bvModal mock: BootstrapVue installs it read-only — mocks cannot
      // overwrite it and only emit VTU warnings. Spy on the real injection
      // (vi.spyOn(wrapper.vm.$bvModal, ...)) if a test needs to assert it.
    });
  };

  beforeEach(() => vi.resetAllMocks());
  afterEach(() => { if (wrapper) wrapper.destroy(); });

  it("submitReview calls createRuleReview with rule id and review payload", async () => {
    const { createRuleReview } = await import("@/api/reviewsApi");
    createRuleReview.mockResolvedValueOnce({ data: {} });

    wrapper = createWrapper();
    wrapper.vm.selectedReviewAction = "approve";
    wrapper.vm.reviewComment = "looks good";
    wrapper.vm.submitReview();

    expect(createRuleReview).toHaveBeenCalledWith(1, {
      component_id: 10,
      action: "approve",
      comment: "looks good",
    });
  });

  it("does not call createRuleReview when comment is empty", async () => {
    const { createRuleReview } = await import("@/api/reviewsApi");

    wrapper = createWrapper();
    wrapper.vm.selectedReviewAction = "approve";
    wrapper.vm.reviewComment = "   ";
    wrapper.vm.submitReview();

    expect(createRuleReview).not.toHaveBeenCalled();
  });

  it("does not call createRuleReview when no action selected", async () => {
    const { createRuleReview } = await import("@/api/reviewsApi");

    wrapper = createWrapper();
    wrapper.vm.selectedReviewAction = null;
    wrapper.vm.reviewComment = "some comment";
    wrapper.vm.submitReview();

    expect(createRuleReview).not.toHaveBeenCalled();
  });
});
