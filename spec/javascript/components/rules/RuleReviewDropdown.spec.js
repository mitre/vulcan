import { describe, it, expect, afterEach, vi, beforeEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleReviewDropdown from "@/components/rules/RuleReviewDropdown.vue";

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

describe("RuleReviewDropdown", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return shallowMount(RuleReviewDropdown, {
      localVue,
      propsData: {
        rule: { id: 5, component_id: 20, status: "Not Yet Determined", locked: false, review_requestor_id: null },
        effectivePermissions: "admin",
        currentUserId: 1,
        ...props,
      },
      stubs: { BDropdown: true, BDropdownForm: true, BFormGroup: true, BFormSelect: true, BFormTextarea: true, BButton: true },
    });
  };

  beforeEach(() => vi.resetAllMocks());
  afterEach(() => { if (wrapper) wrapper.destroy(); });

  it("submitReview calls createRuleReview with rule id and review payload", async () => {
    const { createRuleReview } = await import("@/api/reviewsApi");
    createRuleReview.mockResolvedValueOnce({ data: {} });

    wrapper = createWrapper();
    wrapper.vm.selectedReviewAction = "request_review";
    wrapper.vm.reviewComment = "ready for review";
    wrapper.vm.submitReview();

    expect(createRuleReview).toHaveBeenCalledWith(5, {
      component_id: 20,
      action: "request_review",
      comment: "ready for review",
    });
  });

  it("does not call createRuleReview when comment is empty", async () => {
    const { createRuleReview } = await import("@/api/reviewsApi");

    wrapper = createWrapper();
    wrapper.vm.selectedReviewAction = "approve";
    wrapper.vm.reviewComment = "";
    wrapper.vm.submitReview();

    expect(createRuleReview).not.toHaveBeenCalled();
  });
});
