import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { setActivePinia, createPinia } from "pinia";
import { flushPromises } from "@test/testHelper";
import UserComments from "@/components/users/UserComments.vue";
import { getUserComments } from "@/api/usersApi";

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

vi.mock("@/api/usersApi", () => ({
  getUserComments: vi.fn(() => Promise.resolve({ data: { rows: [], pagination: { total: 0 } } })),
}));

// REQUIREMENT: My Comments — every commenter (including industry
// reviewers using only the viewer role) must be able to see the
// status of comments they posted, where they sit in the triage
// pipeline, and the latest activity. Backed by GET /users/:id/comments
// (Task 09 — already shipped) and consumed by UserProfile.vue.

const SHARED_STUBS = [
  "b-table",
  "b-pagination",
  "b-form-input",
  "b-form-select",
  "b-input-group",
  "b-form-group",
  "b-spinner",
  "b-button",
  "b-badge",
  "b-icon",
  "b-link",
  "b-card",
  "TriageStatusBadge",
  "SectionLabel",
];

const mockResponse = {
  data: {
    rows: [
      {
        id: 142,
        project_id: 4,
        project_name: "Container Platform",
        component_id: 8,
        component_name: "Container Platform",
        rule_id: 17,
        rule_displayed_name: "CNTR-01-000003",
        section: "check_content",
        comment: "Could we soften the severity from CAT II...",
        created_at: "2026-04-29T19:10:59Z",
        triage_status: "pending",
        triage_set_at: null,
        adjudicated_at: null,
        latest_activity_at: null,
      },
      {
        id: 4,
        project_id: 4,
        project_name: "Container Platform",
        component_id: 8,
        component_name: "Container Platform",
        rule_id: 17,
        rule_displayed_name: "CNTR-01-000001",
        section: "vuln_discussion",
        comment: "Vuln discussion para 2 typo",
        created_at: "2026-04-29T19:10:59Z",
        triage_status: "concur",
        triage_set_at: "2026-04-28T10:00:00Z",
        adjudicated_at: "2026-04-29T11:00:00Z",
        latest_activity_at: "2026-04-29T11:00:00Z",
      },
    ],
    pagination: { page: 1, per_page: 25, total: 2 },
  },
};

describe("UserComments", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    getUserComments.mockResolvedValue(mockResponse);
  });

  it("uses commentsStore for data fetching (store integration)", async () => {
    const wrapper = mount(UserComments, {
      propsData: { userId: 7 },
      stubs: SHARED_STUBS,
    });
    await flushPromises();
    expect(wrapper.vm.commentsStore).toBeDefined();
    expect(typeof wrapper.vm.commentsStore.fetchUserComments).toBe("function");
  });

  it("fetches /users/:id/comments on mount", async () => {
    mount(UserComments, {
      propsData: { userId: 7 },
      stubs: SHARED_STUBS,
    });
    await flushPromises();
    expect(getUserComments).toHaveBeenCalledWith(7, expect.objectContaining({ page: 1 }));
  });

  it("renders a row for each comment with rule + project context", async () => {
    // Don't stub b-table here — we need to inspect the actual cell
    // rendering to assert that rule + component + project context is
    // shown to the commenter.
    const wrapper = mount(UserComments, {
      propsData: { userId: 7 },
    });
    await flushPromises();
    const text = wrapper.text();
    expect(text).toContain("CNTR-01-000003");
    expect(text).toContain("Container Platform");
  });

  it("renders an empty-state message when there are no comments", async () => {
    getUserComments.mockResolvedValueOnce({
      data: { rows: [], pagination: { page: 1, per_page: 25, total: 0 } },
    });
    const wrapper = mount(UserComments, {
      propsData: { userId: 7 },
      stubs: SHARED_STUBS,
    });
    await flushPromises();
    expect(wrapper.text()).toMatch(/no comments/i);
  });

  it("links each rule to the component editor with the rule selected", async () => {
    const wrapper = mount(UserComments, {
      propsData: { userId: 7 },
    });
    await flushPromises();
    const ruleLink = wrapper
      .findAll("a")
      .wrappers.find((a) => a.attributes("href") === "/components/8/CNTR-01-000003");
    expect(ruleLink).toBeDefined();
  });

  it("URL-encodes the rule name in the deep link", async () => {
    const wrapper = mount(UserComments, {
      propsData: { userId: 7 },
      stubs: SHARED_STUBS,
    });
    const href = wrapper.vm.ruleHref({
      component_id: 8,
      rule_displayed_name: "FOO BAR/BAZ#1",
    });
    expect(href).toBe(`/components/8/${encodeURIComponent("FOO BAR/BAZ#1")}`);
  });

  it("re-fetches when the triage_status filter changes", async () => {
    const wrapper = mount(UserComments, {
      propsData: { userId: 7 },
      stubs: SHARED_STUBS,
    });
    await flushPromises();
    getUserComments.mockClear();
    wrapper.vm.filterStatus = "pending";
    wrapper.vm.onFilterChanged();
    await flushPromises();
    expect(getUserComments).toHaveBeenCalledWith(7, expect.objectContaining({
      triage_status: "pending",
    }));
  });

  it("surfaces fetch errors via alertOrNotifyResponse", async () => {
    getUserComments.mockRejectedValueOnce({ response: { status: 500, data: {} } });
    const wrapper = mount(UserComments, {
      propsData: { userId: 7 },
      stubs: SHARED_STUBS,
    });
    const alertSpy = vi.spyOn(wrapper.vm, "alertOrNotifyResponse").mockImplementation(() => {});
    getUserComments.mockRejectedValueOnce({ response: { status: 500, data: {} } });
    await wrapper.vm.fetch();
    expect(alertSpy).toHaveBeenCalled();
    alertSpy.mockRestore();
  });
});
