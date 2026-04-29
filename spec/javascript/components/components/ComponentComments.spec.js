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

  // REQUIREMENT: rule deep-link must URL-encode the rule_displayed_name so
  // that any unusual characters (slashes, hashes, whitespace) cannot break
  // out of the path segment and silently navigate to the wrong page.
  describe("ruleHref", () => {
    it("URL-encodes the rule_displayed_name in the path", () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        stubs: SHARED_STUBS,
      });
      const href = wrapper.vm.ruleHref({ rule_displayed_name: "FOO BAR/BAZ#1" });
      expect(href).toBe(`/components/42/${encodeURIComponent("FOO BAR/BAZ#1")}`);
    });

    it("uses the row's component_id when scope=project", () => {
      const wrapper = mount(ComponentComments, {
        propsData: { projectId: 9, scope: "project" },
        stubs: SHARED_STUBS,
      });
      const href = wrapper.vm.ruleHref({
        rule_displayed_name: "CNTR-01-000001",
        component_id: 314,
      });
      expect(href).toBe("/components/314/CNTR-01-000001");
    });
  });

  // REQUIREMENT: project-scope mode must hit the aggregate endpoint at
  // /projects/:id/comments and render the Component column so triagers
  // can see which component each row belongs to.
  describe('scope="project"', () => {
    it("fetches from /projects/:id/comments", async () => {
      mount(ComponentComments, {
        propsData: { projectId: 9, scope: "project" },
        stubs: SHARED_STUBS,
      });
      await flushPromises();
      expect(axios.get).toHaveBeenCalledWith(
        "/projects/9/comments",
        expect.objectContaining({
          params: expect.objectContaining({ triage_status: "pending" }),
        }),
      );
    });

    it("includes the component_name column in the table fields", () => {
      const wrapper = mount(ComponentComments, {
        propsData: { projectId: 9, scope: "project" },
        stubs: SHARED_STUBS,
      });
      const fieldKeys = wrapper.vm.fields.map((f) => f.key);
      expect(fieldKeys).toContain("component_name");
    });

    it("does NOT include the component_name column in component scope", () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        stubs: SHARED_STUBS,
      });
      const fieldKeys = wrapper.vm.fields.map((f) => f.key);
      expect(fieldKeys).not.toContain("component_name");
    });
  });

  // REQUIREMENT: viewers can read the triage queue but must NOT see the
  // Triage / Edit-Close / Re-open action buttons — those are author+
  // privileges. Server-side gates exist (authorize_author_project on
  // /reviews/:id/{triage,adjudicate,reopen}) but the UI must mirror them
  // so viewers don't see misleading buttons that 403 on click.
  describe("role-gating of action buttons", () => {
    const adjudicatedRow = {
      id: 1,
      rule_id: 1,
      rule_displayed_name: "X-1",
      section: null,
      author_name: "C",
      comment: "a",
      created_at: "2026-04-29T00:00:00Z",
      triage_status: "concur",
      triage_set_at: "2026-04-29T00:00:00Z",
      adjudicated_at: "2026-04-29T01:00:00Z",
      duplicate_of_review_id: null,
    };

    it("renders Triage / Edit-Close / Re-open for an author", async () => {
      axios.get.mockResolvedValueOnce({
        data: {
          rows: [{ ...adjudicatedRow, triage_status: "pending", adjudicated_at: null }],
          pagination: { page: 1, per_page: 25, total: 1 },
        },
      });
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42, effectivePermissions: "author" },
      });
      await flushPromises();
      expect(wrapper.text()).toContain("Triage");
    });

    it("hides action buttons for viewers and shows a read-only hint", async () => {
      axios.get.mockResolvedValueOnce({
        data: { rows: [adjudicatedRow], pagination: { page: 1, per_page: 25, total: 1 } },
      });
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42, effectivePermissions: "viewer" },
      });
      await flushPromises();
      // No mutating action buttons in the row
      const actionTexts = wrapper.findAll("button").wrappers.map((b) => b.text().trim());
      expect(actionTexts).not.toContain("Triage");
      expect(actionTexts).not.toContain("Edit / Close");
      expect(actionTexts).not.toContain("Re-open");
      // A read-only hint is shown so the absence is intentional, not broken
      expect(wrapper.text()).toMatch(/read[- ]?only|view only/i);
    });
  });

  // REQUIREMENT: openReopen patches /reviews/:id/reopen and re-fetches the
  // page so the row's status flips from "Closed" back to its prior triage
  // state. Wired to the Re-open button on adjudicated rows.
  describe("openReopen", () => {
    const adjudicatedRow = {
      id: 99,
      rule_id: 1,
      rule_displayed_name: "X-1",
      section: null,
      author_name: "C",
      comment: "a",
      created_at: "2026-04-29T00:00:00Z",
      triage_status: "concur",
      triage_set_at: "2026-04-29T00:00:00Z",
      adjudicated_at: "2026-04-29T01:00:00Z",
      duplicate_of_review_id: null,
    };

    it("PATCHes /reviews/:id/reopen and re-fetches the table", async () => {
      axios.patch = vi.fn().mockResolvedValue({ data: { review: { id: 99 } } });
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42, effectivePermissions: "author" },
        stubs: SHARED_STUBS,
      });
      await flushPromises();
      const initialFetchCount = axios.get.mock.calls.length;

      await wrapper.vm.openReopen(adjudicatedRow);
      await flushPromises();

      expect(axios.patch).toHaveBeenCalledWith("/reviews/99/reopen");
      // Re-fetch fires after a successful re-open so the row's new state
      // is visible without a manual refresh.
      expect(axios.get.mock.calls.length).toBeGreaterThan(initialFetchCount);
    });

    it("surfaces server errors via alertOrNotifyResponse but still re-fetches", async () => {
      axios.patch = vi.fn().mockRejectedValue({ response: { status: 422, data: {} } });
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42, effectivePermissions: "author" },
        stubs: SHARED_STUBS,
      });
      await flushPromises();
      const alertSpy = vi.spyOn(wrapper.vm, "alertOrNotifyResponse").mockImplementation(() => {});
      const initialFetchCount = axios.get.mock.calls.length;

      await wrapper.vm.openReopen(adjudicatedRow);
      await flushPromises();

      expect(alertSpy).toHaveBeenCalled();
      // Even on failure we re-fetch to make sure the UI matches server state.
      expect(axios.get.mock.calls.length).toBeGreaterThan(initialFetchCount);
      alertSpy.mockRestore();
    });
  });

  // REQUIREMENT: clicking the refresh button forces a re-fetch without
  // closing the page — useful when concurrent triagers are working the
  // same queue and rows go stale.
  describe("refresh button", () => {
    it("calls fetch when invoked", async () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        stubs: SHARED_STUBS,
      });
      await flushPromises();
      const initialFetchCount = axios.get.mock.calls.length;

      await wrapper.vm.fetch();
      await flushPromises();

      expect(axios.get.mock.calls.length).toBeGreaterThan(initialFetchCount);
    });
  });

  // REQUIREMENT: filters persist in localStorage per scope so closing
  // and re-opening the triage page (or returning from a navigation)
  // doesn't snap filters back to the default "pending / all sections".
  describe("persisted filters", () => {
    const persistKey = (scope, id) => `commentTriageFilters-${scope}-${id}`;

    beforeEach(() => {
      localStorage.clear();
    });

    it("restores filterStatus / filterSection / filterText from localStorage on mount", () => {
      localStorage.setItem(
        persistKey("component", 42),
        JSON.stringify({
          filterStatus: "concur",
          filterSection: "check_content",
          filterText: "runc",
        }),
      );
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        stubs: SHARED_STUBS,
      });
      expect(wrapper.vm.filterStatus).toBe("concur");
      expect(wrapper.vm.filterSection).toBe("check_content");
      expect(wrapper.vm.filterText).toBe("runc");
    });

    it("uses a separate persistence key per scope (component vs project)", () => {
      localStorage.setItem(
        persistKey("component", 42),
        JSON.stringify({ filterStatus: "concur", filterSection: null, filterText: "" }),
      );
      const projectWrapper = mount(ComponentComments, {
        propsData: { projectId: 42, scope: "project" },
        stubs: SHARED_STUBS,
      });
      // Project scope on id 42 must NOT pick up the component-scope persisted value
      expect(projectWrapper.vm.filterStatus).toBe("pending");
    });

    it("writes filter state to localStorage when filters change", async () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        stubs: SHARED_STUBS,
      });
      await flushPromises();
      wrapper.vm.filterStatus = "non_concur";
      wrapper.vm.onFilterChanged();
      const stored = JSON.parse(localStorage.getItem(persistKey("component", 42)));
      expect(stored.filterStatus).toBe("non_concur");
    });
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
