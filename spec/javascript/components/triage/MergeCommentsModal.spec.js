import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import MergeCommentsModal from "@/components/triage/MergeCommentsModal.vue";

const sample = (overrides = {}) => ({
  id: 1,
  comment: "logging not applicable",
  author_name: "Brian Snodgrass",
  rule_displayed_name: "CNTR-00-001049",
  created_at: "2026-05-10T10:00:00Z",
  ...overrides,
});

const factory = (selectedReviews = []) =>
  mount(MergeCommentsModal, {
    localVue,
    propsData: { selectedReviews },
    // b-modal is stubbed so its $bvModal portal/event plumbing doesn't run.
    stubs: { "b-modal": { template: "<div><slot /></div>" } },
  });

describe("MergeCommentsModal", () => {
  it("renders a row per selected review", () => {
    const wrapper = factory([sample({ id: 1 }), sample({ id: 2 }), sample({ id: 3 })]);
    expect(wrapper.findAll('[data-testid="merge-row"]').length).toBe(3);
  });

  it("defaults the survivor to the oldest-posted comment", () => {
    const wrapper = factory([
      sample({ id: 2, created_at: "2026-05-12T10:00:00Z" }),
      sample({ id: 1, created_at: "2026-05-10T10:00:00Z" }), // oldest
      sample({ id: 3, created_at: "2026-05-14T10:00:00Z" }),
    ]);
    expect(wrapper.vm.survivorId).toBe(1);
  });

  it("shows the selected count and computed duplicate count", () => {
    const wrapper = factory([sample({ id: 1 }), sample({ id: 2 }), sample({ id: 3 })]);
    const text = wrapper.find('[data-testid="merge-count"]').text();
    expect(text).toContain("3 comments selected");
    expect(text).toContain("2 will become duplicates");
  });

  it("disables confirm when fewer than 2 reviews are selected", () => {
    const wrapper = factory([sample({ id: 1 })]);
    expect(wrapper.vm.canConfirm).toBe(false);
  });

  it("emits submit with review_ids and survivor_id on confirm", () => {
    const wrapper = factory([sample({ id: 1 }), sample({ id: 2 }), sample({ id: 3 })]);
    wrapper.vm.survivorId = 2;
    wrapper.vm.confirm();

    expect(wrapper.emitted("submit")).toBeTruthy();
    expect(wrapper.emitted("submit")[0][0]).toEqual({
      review_ids: [1, 2, 3],
      survivor_id: 2,
    });
  });

  it("emits hidden when the modal closes", async () => {
    const wrapper = factory([sample({ id: 1 }), sample({ id: 2 })]);
    wrapper.vm.onHidden();
    expect(wrapper.emitted("hidden")).toBeTruthy();
  });
});
