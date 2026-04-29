import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import axios from "axios";
import ComponentComments from "@/components/components/ComponentComments.vue";

vi.mock("axios");

// Flush both microtasks (axios .then chain) and the next Vue tick so the
// reactive state from a resolved fetch settles before assertions run.
// @vue/test-utils for Vue 2 doesn't export flushPromises, so this is the
// project-portable equivalent.
const flushPromises = async (wrapper) => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  if (wrapper) await wrapper.vm.$nextTick();
};

const SHARED_STUBS = [
  "b-table",
  "b-pagination",
  "b-form-input",
  "b-form-select",
  "b-input-group",
  "b-form-group",
  "b-spinner",
  "b-button",
  "TriageStatusBadge",
  "SectionLabel",
  "CommentTriageModal",
];

const mockResponse = {
  data: {
    rows: [
      {
        id: 142,
        rule_id: 7,
        rule_displayed_name: "CRI-O-000050",
        section: "check_content",
        author_name: "John Doe",
        comment: "Check text mentions runc 1.0...",
        created_at: "2026-04-27T10:00:00Z",
        triage_status: "pending",
        triage_set_at: null,
        adjudicated_at: null,
        duplicate_of_review_id: null,
      },
      {
        id: 141,
        rule_id: 8,
        rule_displayed_name: "CRI-O-000051",
        section: "severity",
        author_name: "Sarah K",
        comment: "Could we soften...",
        created_at: "2026-04-26T10:00:00Z",
        triage_status: "concur_with_comment",
        triage_set_at: "2026-04-27T11:00:00Z",
        adjudicated_at: null,
      },
    ],
    pagination: { page: 1, per_page: 25, total: 2 },
  },
};

describe("ComponentComments", () => {
  beforeEach(() => {
    axios.get.mockResolvedValue(mockResponse);
  });

  it("fetches with default triage_status=pending on mount", async () => {
    mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises();
    expect(axios.get).toHaveBeenCalledWith(
      "/components/42/comments",
      expect.objectContaining({
        params: expect.objectContaining({ triage_status: "pending", page: 1 }),
      }),
    );
  });

  it("does NOT hardcode DISA labels in the rendered template (display goes through TriageStatusBadge)", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises();
    // TriageStatusBadge / SectionLabel are stubbed in this test, so any
    // appearance of DISA terms in the rendered HTML would mean the parent
    // template hardcoded them — which it shouldn't.
    const html = wrapper.html();
    expect(html).not.toMatch(/\bConcur\b/);
    expect(html).not.toMatch(/\bAdjudicated\b/);
    expect(html).not.toMatch(/\bNon-?concur\b/i);
  });

  it("emits jump-to-rule when openTriageFor resolves a row's rule click", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises();
    wrapper.vm.$emit("jump-to-rule", 7);
    expect(wrapper.emitted("jump-to-rule")).toEqual([[7]]);
  });

  it("re-fetches when filterText changes", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises();
    axios.get.mockClear();
    wrapper.vm.filterText = "apple";
    wrapper.vm.onFilterChanged();
    await flushPromises();
    expect(axios.get).toHaveBeenCalledWith(
      "/components/42/comments",
      expect.objectContaining({
        params: expect.objectContaining({ q: "apple" }),
      }),
    );
  });

  it("re-fetches when filterStatus changes and resets page to 1", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises();
    wrapper.vm.page = 5;
    axios.get.mockClear();
    wrapper.vm.filterStatus = "concur";
    wrapper.vm.onFilterChanged();
    await flushPromises();
    expect(wrapper.vm.page).toBe(1);
    expect(axios.get).toHaveBeenCalledWith(
      "/components/42/comments",
      expect.objectContaining({
        params: expect.objectContaining({ triage_status: "concur", page: 1 }),
      }),
    );
  });

  it("opens the triage modal via $bvModal.show when openTriageFor is called", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises();
    // BootstrapVue installs $bvModal as a read-only instance property, so
    // we spy on its show method directly after mount.
    const showSpy = vi.spyOn(wrapper.vm.$bvModal, "show").mockImplementation(() => {});
    wrapper.vm.openTriageFor(mockResponse.data.rows[0]);
    expect(wrapper.vm.selectedRow.id).toBe(142);
    expect(showSpy).toHaveBeenCalledWith("comment-triage-modal");
    showSpy.mockRestore();
  });

  it("surfaces fetch errors via alertOrNotifyResponse without crashing", async () => {
    axios.get.mockRejectedValueOnce({ response: { status: 500, data: {} } });
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    // The mixin method is on the instance after mount, not on the component
    // definition's methods bag — spy through the wrapper.
    const alertSpy = vi.spyOn(wrapper.vm, "alertOrNotifyResponse").mockImplementation(() => {});
    // Trigger another fetch so the rejection-handling path runs while spy is active
    axios.get.mockRejectedValueOnce({ response: { status: 500, data: {} } });
    await wrapper.vm.fetch();
    expect(alertSpy).toHaveBeenCalled();
    alertSpy.mockRestore();
  });
});
