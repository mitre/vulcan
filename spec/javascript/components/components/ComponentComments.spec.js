import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { setActivePinia, createPinia } from "pinia";
import { flushPromises } from "@test/testHelper";
import ComponentComments from "@/components/components/ComponentComments.vue";
import { getComments } from "@/api/componentsApi";
import { getProjectComments } from "@/api/projectsApi";
import { reopenReview, bulkTriageReviews } from "@/api/reviewsApi";

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

vi.mock("@/api/componentsApi", () => ({
  getComments: vi.fn(() => Promise.resolve({ data: { rows: [], pagination: { total: 0 } } })),
}));

vi.mock("@/api/projectsApi", () => ({
  getProjectComments: vi.fn(() =>
    Promise.resolve({ data: { rows: [], pagination: { total: 0 } } }),
  ),
}));

vi.mock("@/api/reviewsApi", () => ({
  reopenReview: vi.fn(() => Promise.resolve({ data: { review: { id: 99 } } })),
  bulkTriageReviews: vi.fn(() => Promise.resolve({ data: {} })),
  mergeReviews: vi.fn(() => Promise.resolve({ data: {} })),
}));

// Spy-wrap (real implementations preserved) so tests can pin that dates,
// permissions, and the reply composer flow through the composables.
vi.mock("@/composables/useDateFormat", { spy: true });
vi.mock("@/composables/usePermissions", { spy: true });
vi.mock("@/composables/useReplyComposer", { spy: true });
import { useDateFormat } from "@/composables/useDateFormat";
import { usePermissions } from "@/composables/usePermissions";
import { useReplyComposer } from "@/composables/useReplyComposer";

// Flush both microtasks (axios .then chain) and the next Vue tick so the
// reactive state from a resolved fetch settles before assertions run.
// @vue/test-utils for Vue 2 doesn't export flushPromises, so this is the
// project-portable equivalent.
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
        reactions: { up: 0, down: 0, mine: null },
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
        reactions: { up: 0, down: 0, mine: null },
      },
    ],
    pagination: { page: 1, per_page: 25, total: 2 },
    status_counts: { pending: 1, concur_with_comment: 1 },
  },
};

describe("ComponentComments", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    getComments.mockResolvedValue(mockResponse);
  });

  it("fetches with default triage_status=all on mount", async () => {
    mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises();
    expect(getComments).toHaveBeenCalledWith(
      42,
      expect.objectContaining({
        triage_status: "all",
        page: 1,
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
    getComments.mockClear();
    wrapper.vm.filterText = "apple";
    wrapper.vm.onFilterChanged();
    await flushPromises();
    expect(getComments).toHaveBeenCalledWith(
      42,
      expect.objectContaining({
        q: "apple",
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
    getComments.mockClear();
    wrapper.vm.filterStatus = "concur";
    wrapper.vm.onFilterChanged();
    await flushPromises();
    expect(wrapper.vm.page).toBe(1);
    expect(getComments).toHaveBeenCalledWith(
      42,
      expect.objectContaining({
        triage_status: "concur",
        page: 1,
      }),
    );
  });

  it("enters split mode when openTriageFor is called", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises();
    wrapper.vm.openTriageFor(mockResponse.data.rows[0]);
    expect(wrapper.vm.splitMode).toBe(true);
    expect(wrapper.vm.splitCommentId).toBe(142);
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
      expect(getProjectComments).toHaveBeenCalledWith(
        9,
        expect.objectContaining({
          triage_status: "all",
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
      getComments.mockResolvedValueOnce({
        data: {
          rows: [{ ...adjudicatedRow, triage_status: "pending", adjudicated_at: null }],
          pagination: { page: 1, per_page: 25, total: 1 },
        },
      });
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        provide: { effectivePermissions: "author" },
      });
      await flushPromises();
      expect(wrapper.text()).toContain("Triage");
    });

    it("hides action buttons for viewers and shows a read-only hint", async () => {
      getComments.mockResolvedValueOnce({
        data: { rows: [adjudicatedRow], pagination: { page: 1, per_page: 25, total: 1 } },
      });
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        provide: { effectivePermissions: "viewer" },
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
      reopenReview.mockResolvedValue({ data: { review: { id: 99 } } });
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        provide: { effectivePermissions: "author" },
        stubs: SHARED_STUBS,
      });
      await flushPromises();
      const initialFetchCount = getComments.mock.calls.length;

      await wrapper.vm.openReopen(adjudicatedRow);
      await flushPromises();

      expect(reopenReview).toHaveBeenCalledWith(99);
      expect(getComments.mock.calls.length).toBe(initialFetchCount + 1);
    });

    it("surfaces server errors via alertOrNotifyResponse but still re-fetches", async () => {
      reopenReview.mockRejectedValue({ response: { status: 422, data: {} } });
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        provide: { effectivePermissions: "author" },
        stubs: SHARED_STUBS,
      });
      await flushPromises();
      const alertSpy = vi.spyOn(wrapper.vm, "alertOrNotifyResponse").mockImplementation(() => {});
      const initialFetchCount = getComments.mock.calls.length;

      await wrapper.vm.openReopen(adjudicatedRow);
      await flushPromises();

      expect(alertSpy).toHaveBeenCalled();
      // Even on failure we re-fetch to make sure the UI matches server state.
      expect(getComments.mock.calls.length).toBe(initialFetchCount + 1);
      alertSpy.mockRestore();
    });
  });

  // modal events update the row in
  // place (no full-table refetch) so triage/adjudicate is one round
  // trip instead of two. The blueprint expansion (.20 primary
  // deliverable) ensures the response payload carries enough fields
  // to refresh in place.
  describe("onTriaged / onAdjudicated update row in place (.20)", () => {
    const initialRow = {
      id: 142,
      rule_id: 7,
      rule_displayed_name: "X-7",
      section: "check_content",
      author_name: "John Doe",
      comment: "Original comment text",
      created_at: "2026-04-27T10:00:00Z",
      triage_status: "pending",
      triage_set_at: null,
      adjudicated_at: null,
      duplicate_of_review_id: null,
      triager_display_name: null,
      triager_imported: false,
      adjudicator_display_name: null,
      adjudicator_imported: false,
      commenter_display_name: "John Doe",
      commenter_imported: false,
    };

    const triagedPayload = {
      id: 142,
      rule_id: 7,
      action: "comment",
      comment: "Original comment text",
      created_at: "2026-04-27T10:00:00Z",
      triage_status: "concur",
      triage_set_at: "2026-04-30T11:00:00Z",
      triage_set_by_id: 5,
      adjudicated_at: null,
      section: "check_content",
      responding_to_review_id: null,
      duplicate_of_review_id: null,
      name: "John Doe",
      author_name: "John Doe",
      triager_display_name: "Triager Tee",
      triager_imported: false,
      adjudicator_display_name: null,
      adjudicator_imported: false,
      commenter_display_name: "John Doe",
      commenter_imported: false,
    };

    function mountWithRow() {
      getComments.mockResolvedValueOnce({
        data: {
          rows: [initialRow],
          pagination: { page: 1, per_page: 25, total: 1 },
        },
      });
      return mount(ComponentComments, {
        propsData: { componentId: 42 },
        provide: { effectivePermissions: "author" },
        stubs: SHARED_STUBS,
      });
    }

    it("onTriaged updates the matching row's triage_status without re-fetching", async () => {
      const wrapper = mountWithRow();
      await flushPromises();
      const fetchesAfterMount = getComments.mock.calls.length;

      await wrapper.vm.onTriaged(triagedPayload);
      await flushPromises();

      expect(getComments.mock.calls.length).toBe(fetchesAfterMount); // no extra fetch
      const refreshed = wrapper.vm.rows.find((r) => r.id === 142);
      expect(refreshed.triage_status).toBe("concur");
      expect(refreshed.triager_display_name).toBe("Triager Tee");
    });

    it("normalizes payload in updateRowInPlace — camelCase aliases match fresh values", async () => {
      const wrapper = mountWithRow();
      await flushPromises();

      await wrapper.vm.onTriaged(triagedPayload);
      await flushPromises();

      const refreshed = wrapper.vm.rows.find((r) => r.id === 142);
      expect(refreshed.triageStatus).toBe("concur");
      expect(refreshed.triageStatus).toBe(refreshed.triage_status);
    });

    it("preserves rule_displayed_name (computed in paginated_comments, not in blueprint)", async () => {
      const wrapper = mountWithRow();
      await flushPromises();

      await wrapper.vm.onTriaged(triagedPayload);
      await flushPromises();

      const refreshed = wrapper.vm.rows.find((r) => r.id === 142);
      expect(refreshed.rule_displayed_name).toBe("X-7");
    });

    it("onAdjudicated updates the matching row's adjudicated_at without re-fetching", async () => {
      const wrapper = mountWithRow();
      await flushPromises();
      const fetchesAfterMount = getComments.mock.calls.length;

      const adjudicatedPayload = {
        ...triagedPayload,
        adjudicated_at: "2026-04-30T12:00:00Z",
        adjudicator_display_name: "Adjudicator Aye",
      };
      await wrapper.vm.onAdjudicated(adjudicatedPayload);
      await flushPromises();

      expect(getComments.mock.calls.length).toBe(fetchesAfterMount);
      const refreshed = wrapper.vm.rows.find((r) => r.id === 142);
      expect(refreshed.adjudicated_at).toBe("2026-04-30T12:00:00Z");
      expect(refreshed.adjudicator_display_name).toBe("Adjudicator Aye");
    });

    it("falls back to fetch when the payload is missing (defensive)", async () => {
      const wrapper = mountWithRow();
      await flushPromises();
      const fetchesAfterMount = getComments.mock.calls.length;

      await wrapper.vm.onTriaged(undefined);
      await flushPromises();

      expect(getComments.mock.calls.length).toBe(fetchesAfterMount + 1);
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
      const initialFetchCount = getComments.mock.calls.length;

      await wrapper.vm.fetch();
      await flushPromises();

      expect(getComments.mock.calls.length).toBe(initialFetchCount + 1);
    });
  });

  // REQUIREMENT: the DISA disposition matrix CSV export (Task 29) is
  // available to authors+ on a single-component triage queue. The button
  // links to /components/:id/export/disposition_csv with the active
  // triage_status filter passed through.
  describe("disposition CSV export button", () => {
    it("computes a path-based export URL with the active filterStatus", () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42, scope: "component" },
        provide: { effectivePermissions: "author" },
        stubs: SHARED_STUBS,
      });
      wrapper.vm.filterStatus = "concur";
      expect(wrapper.vm.dispositionExportUrl).toBe(
        "/components/42/export/disposition_csv?triage_status=concur",
      );
    });

    it("omits the triage_status query param when filter is 'all'", () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42, scope: "component" },
        provide: { effectivePermissions: "author" },
        stubs: SHARED_STUBS,
      });
      wrapper.vm.filterStatus = "all";
      expect(wrapper.vm.dispositionExportUrl).toBe("/components/42/export/disposition_csv");
    });

    // Don't stub b-button here so the :href path renders as an <a>.
    const noBtnStubs = SHARED_STUBS.filter((s) => s !== "b-button");

    it("renders the Export CSV button for author+ in component scope", async () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42, scope: "component" },
        provide: { effectivePermissions: "author" },
        stubs: noBtnStubs,
      });
      await flushPromises();
      const btn = wrapper.findAll("a").wrappers.find((a) => a.text().includes("Export CSV"));
      expect(btn).toBeDefined();
      expect(btn.attributes("href")).toContain("/components/42/export/disposition_csv");
    });

    it("hides the Export CSV button for viewer role (server enforces 403; UI matches)", async () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42, scope: "component" },
        provide: { effectivePermissions: "viewer" },
        stubs: noBtnStubs,
      });
      await flushPromises();
      const btn = wrapper.findAll("a").wrappers.find((a) => a.text().includes("Export CSV"));
      expect(btn).toBeUndefined();
    });

    it("renders the Export CSV button in project (aggregate) scope and links to the project endpoint", async () => {
      const wrapper = mount(ComponentComments, {
        propsData: { projectId: 7, scope: "project" },
        provide: { effectivePermissions: "author" },
        stubs: noBtnStubs,
      });
      await flushPromises();
      const btn = wrapper.findAll("a").wrappers.find((a) => a.text().includes("Export CSV"));
      expect(btn).toBeDefined();
      expect(btn.attributes("href")).toContain("/projects/7/export/disposition_csv");
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
      expect(projectWrapper.vm.filterStatus).toBe("all");
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

  // REQUIREMENT: default sort is by # ascending (oldest/lowest first)
  // so the queue reads top-to-bottom in submission order.
  it("defaults to sorting by id ascending", () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    expect(wrapper.vm.sortBy).toBe("id");
    expect(wrapper.vm.sortDesc).toBe(false);
  });

  // REQUIREMENT: comment # column must be sortable so triagers can
  // order the queue by comment ID (arrival order, oldest-first, etc.).
  it("marks the # (id) column as sortable", () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    const idField = wrapper.vm.fields.find((f) => f.key === "id");
    expect(idField).toBeDefined();
    expect(idField.sortable).toBe(true);
  });

  // REQUIREMENT: full comment text must be visible in the table cell —
  // truncation to 80 chars + "..." hides context that triagers need
  // to see without opening the modal.
  it("renders full comment text without truncation", async () => {
    const longComment = "A".repeat(200);
    getComments.mockResolvedValueOnce({
      data: {
        rows: [
          {
            id: 1,
            rule_id: 1,
            rule_displayed_name: "X-1",
            commentable_type: "Rule",
            section: null,
            author_name: "Tester",
            comment: longComment,
            created_at: "2026-05-01T00:00:00Z",
            triage_status: "pending",
            adjudicated_at: null,
          },
        ],
        pagination: { page: 1, per_page: 25, total: 1 },
      },
    });
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
        provide: { effectivePermissions: "author" },
    });
    await flushPromises(wrapper);
    expect(wrapper.text()).toContain(longComment);
  });

  // REQUIREMENT: section filter and search box hidden in split mode —
  // the queue nav handles navigation, these controls are redundant.
  it("hides section filter and search in split mode", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises();
    wrapper.vm.splitMode = true;
    await wrapper.vm.$nextTick();
    expect(wrapper.vm.splitModeFilterVisible).toBe(false);
  });

  it("shows section filter and search in table mode", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises();
    expect(wrapper.vm.splitModeFilterVisible).toBe(true);
  });

  it("surfaces fetch errors via alertOrNotifyResponse without crashing", async () => {
    getComments.mockRejectedValueOnce({ response: { status: 500, data: {} } });
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    // The mixin method is on the instance after mount, not on the component
    // definition's methods bag — spy through the wrapper.
    const alertSpy = vi.spyOn(wrapper.vm, "alertOrNotifyResponse").mockImplementation(() => {});
    // Trigger another fetch so the rejection-handling path runs while spy is active
    getComments.mockRejectedValueOnce({ response: { status: 500, data: {} } });
    await wrapper.vm.fetch();
    expect(alertSpy).toHaveBeenCalled();
    alertSpy.mockRestore();
  });

  // ── Filter state (pills are the sole filter control) ─────────────

  it("does not render a Show Resolved toggle (pills replace it)", async () => {
    getComments.mockResolvedValue({ data: { rows: [], pagination: { total: 0 } } });
    const wrapper = mount(ComponentComments, { propsData: { componentId: 42 } });
    await flushPromises(wrapper);
    expect(wrapper.find("[data-testid='show-resolved-toggle']").exists()).toBe(false);
  });

  it("defaults filterStatus to 'all'", async () => {
    localStorage.clear();
    getComments.mockResolvedValue({ data: { rows: [], pagination: { total: 0 } } });
    const wrapper = mount(ComponentComments, { propsData: { componentId: 42 } });
    await flushPromises(wrapper);
    expect(wrapper.vm.filterStatus).toBe("all");
  });

  // ── CommentProgressBar integration ──────────────────────────────────

  it("renders CommentProgressBar with status_counts from API response", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises(wrapper);
    const bar = wrapper.findComponent({ name: "CommentProgressBar" });
    expect(bar.exists()).toBe(true);
    expect(bar.props("statusCounts")).toEqual({ pending: 1, concur_with_comment: 1 });
  });

  it("hides CommentProgressBar when status_counts is empty", async () => {
    getComments.mockResolvedValue({
      data: { rows: [], pagination: { total: 0 }, status_counts: {} },
    });
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises(wrapper);
    const bar = wrapper.findComponent({ name: "CommentProgressBar" });
    expect(bar.exists()).toBe(false);
  });

  it("updates CommentProgressBar when data is refetched", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises(wrapper);
    expect(wrapper.vm.statusCounts).toEqual({ pending: 1, concur_with_comment: 1 });

    getComments.mockResolvedValueOnce({
      data: {
        rows: [],
        pagination: { total: 0 },
        status_counts: { pending: 0, concur: 5 },
      },
    });
    await wrapper.vm.fetch();
    await flushPromises(wrapper);
    expect(wrapper.vm.statusCounts).toEqual({ pending: 0, concur: 5 });
  });

  it("sets filterStatus when progress bar pill is clicked", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises(wrapper);
    wrapper.vm.onPillFilter("non_concur");
    expect(wrapper.vm.filterStatus).toBe("non_concur");
  });

  it("passes filterStatus as activeFilter to CommentProgressBar", async () => {
    localStorage.clear();
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises(wrapper);
    const bar = wrapper.findComponent({ name: "CommentProgressBar" });
    expect(bar.props("activeFilter")).toBe("all");
  });

  // ── Pill filter sets filterStatus (no separate indicator needed) ──

  it("pill click sets filterStatus and expands accordions in by-rule view", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises(wrapper);
    wrapper.vm.viewMode = "by-rule";
    wrapper.vm.onPillFilter("non_concur");
    expect(wrapper.vm.filterStatus).toBe("non_concur");
    expect(wrapper.vm.allExpanded).toBe(true);
  });

  it("clicking active pill toggles back to 'all'", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises(wrapper);
    wrapper.vm.onPillFilter("non_concur");
    expect(wrapper.vm.filterStatus).toBe("non_concur");
    wrapper.vm.onPillFilter("all");
    expect(wrapper.vm.filterStatus).toBe("all");
  });

  describe("commenter email visibility", () => {
    it("stores author_email in row data after fetch", async () => {
      getComments.mockResolvedValueOnce({
        data: {
          rows: [
            {
              id: 900,
              rule_id: 7,
              rule_displayed_name: "CNTR-00-000010",
              section: "fix",
              author_name: "John Osborne",
              author_email: "josborne@chainguard.dev",
              comment: "Test comment",
              created_at: "2026-05-19T16:15:00Z",
              triage_status: "pending",
            },
          ],
          pagination: { page: 1, per_page: 25, total: 1 },
          status_counts: { pending: 1 },
        },
      });

      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 29 },
        stubs: SHARED_STUBS,
      });
      await flushPromises(wrapper);

      expect(wrapper.vm.rows[0].author_email).toBe("josborne@chainguard.dev");
      expect(wrapper.vm.rows[0].author_name).toBe("John Osborne");
    });

    it("stores imported email when user is not on this instance", async () => {
      getComments.mockResolvedValueOnce({
        data: {
          rows: [
            {
              id: 901,
              rule_id: 7,
              rule_displayed_name: "CNTR-00-000010",
              section: "fix",
              author_name: null,
              author_email: "external@example.com",
              commenter_display_name: "External User",
              commenter_imported: true,
              comment: "Imported comment",
              created_at: "2026-05-19T16:15:00Z",
              triage_status: "pending",
            },
          ],
          pagination: { page: 1, per_page: 25, total: 1 },
          status_counts: { pending: 1 },
        },
      });

      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 29 },
        stubs: SHARED_STUBS,
      });
      await flushPromises(wrapper);

      expect(wrapper.vm.rows[0].author_email).toBe("external@example.com");
    });

    it("includes commentExpanded in data for truncation state", () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 29 },
        stubs: SHARED_STUBS,
      });
      expect(wrapper.vm.commentExpanded).toEqual({});
    });

    it("table fields include author_name column", () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 29 },
        stubs: SHARED_STUBS,
      });
      const authorField = wrapper.vm.fields.find((f) => f.key === "author_name");
      expect(authorField).toBeDefined();
      expect(authorField.label).toBe("Author");
    });
  });

  describe("search result selection (rule_id filtering)", () => {
    it("sets filterRuleId from comment search result", () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 29, componentPrefix: "CNTR" },
        stubs: SHARED_STUBS,
      });
      wrapper.vm.onCommentSearchResultSelected({ rule_id: 42, rule_displayed_name: "CNTR-000050" });
      expect(wrapper.vm.filterRuleId).toBe(42);
    });

    it("sets filterText from searchQuery in comment search result", () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 29, componentPrefix: "CNTR" },
        stubs: SHARED_STUBS,
      });
      wrapper.vm.onCommentSearchResultSelected({
        searchQuery: "runc",
        rule_id: 42,
        rule_displayed_name: "CNTR-000050",
      });
      expect(wrapper.vm.filterText).toBe("runc");
    });

    it("sets filterRuleDisplayName from comment search result", () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 29, componentPrefix: "CNTR" },
        stubs: SHARED_STUBS,
      });
      wrapper.vm.onCommentSearchResultSelected({ rule_id: 42, rule_displayed_name: "CNTR-000050" });
      expect(wrapper.vm.filterRuleDisplayName).toBe("CNTR-000050");
    });

    it("clears filterRuleId when clearRuleFilter is called", () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 29, componentPrefix: "CNTR" },
        stubs: SHARED_STUBS,
      });
      wrapper.vm.filterRuleId = 42;
      wrapper.vm.filterRuleDisplayName = "CNTR-000050";
      wrapper.vm.clearRuleFilter();
      expect(wrapper.vm.filterRuleId).toBeNull();
      expect(wrapper.vm.filterRuleDisplayName).toBe("");
    });

    it("sends rule_id param in fetch when filterRuleId is set", async () => {
      getComments.mockResolvedValue(mockResponse);
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 29, componentPrefix: "CNTR" },
        stubs: SHARED_STUBS,
      });
      wrapper.vm.filterRuleId = 42;
      await wrapper.vm.fetch();
      const callArgs = getComments.mock.calls[getComments.mock.calls.length - 1];
      expect(callArgs[1].rule_id).toBe(42);
    });

    it("does NOT send rule_id param when filterRuleId is null", async () => {
      getComments.mockResolvedValue(mockResponse);
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 29, componentPrefix: "CNTR" },
        stubs: SHARED_STUBS,
      });
      wrapper.vm.filterRuleId = null;
      await wrapper.vm.fetch();
      const callArgs = getComments.mock.calls[getComments.mock.calls.length - 1];
      expect(callArgs[1].rule_id).toBeUndefined();
    });
  });

  // ── 05f.28.5: viewParentComments + exitSplitMode ───────────────────

  it("viewParentComments swaps filter to parent rule", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises(wrapper);
    wrapper.vm.filterRuleId = 100;
    wrapper.vm.filterParentRuleId = 200;
    wrapper.vm.filterParentDisplayName = "PARENT-001";
    wrapper.vm.viewParentComments();
    expect(wrapper.vm.filterRuleId).toBe(200);
    expect(wrapper.vm.filterRuleDisplayName).toBe("PARENT-001");
  });

  it("exitSplitMode resets split state and emits", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises(wrapper);
    wrapper.vm.splitMode = true;
    wrapper.vm.splitCommentId = 42;
    wrapper.vm.exitSplitMode();
    expect(wrapper.vm.splitMode).toBe(false);
    expect(wrapper.vm.splitCommentId).toBeNull();
    expect(wrapper.emitted("split-mode-changed")[0][0]).toBe(false);
  });

  // ── Fix 1: Hide Expand All in split mode ───────────────────────────

  it("hides Expand All toggle when in split-pane mode", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises(wrapper);
    wrapper.vm.viewMode = "by-rule";
    wrapper.vm.splitMode = true;
    await wrapper.vm.$nextTick();
    expect(wrapper.find("[data-testid='expand-all']").exists()).toBe(false);
  });

  it("shows Expand All toggle in by-rule mode when NOT in split mode", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: SHARED_STUBS,
    });
    await flushPromises(wrapper);
    wrapper.vm.viewMode = "by-rule";
    wrapper.vm.splitMode = false;
    await wrapper.vm.$nextTick();
    expect(wrapper.find("[data-testid='expand-all']").exists()).toBe(true);
  });

  // ── Fix 3: Right-align Export CSV + Comment in split mode ──────────

  it("adds ml-auto to export button in split mode", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
        provide: { effectivePermissions: "author" },
      stubs: SHARED_STUBS,
    });
    await flushPromises(wrapper);
    wrapper.vm.splitMode = true;
    await wrapper.vm.$nextTick();
    expect(wrapper.vm.canExportDisposition).toBe(true);
    expect(wrapper.vm.splitMode).toBe(true);
  });

  it("adds ml-auto to comment button when export hidden in split mode", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
        provide: { effectivePermissions: "viewer" },
      stubs: SHARED_STUBS,
    });
    await flushPromises(wrapper);
    wrapper.vm.splitMode = true;
    await wrapper.vm.$nextTick();
    expect(wrapper.vm.canExportDisposition).toBe(false);
    expect(wrapper.vm.splitMode).toBe(true);
  });

  // ── Project scope: table only, triage navigates to component ──────

  describe("project scope", () => {
    it("hides view mode toggle in project scope", async () => {
      const wrapper = mount(ComponentComments, {
        propsData: { projectId: 6, scope: "project" },
        stubs: SHARED_STUBS,
      });
      await flushPromises(wrapper);
      expect(wrapper.find("[data-testid='view-mode-table']").exists()).toBe(false);
      expect(wrapper.find("[data-testid='view-mode-by-rule']").exists()).toBe(false);
    });

    it("navigates to component triage instead of entering split mode", async () => {
      const wrapper = mount(ComponentComments, {
        propsData: { projectId: 6, scope: "project" },
        provide: { effectivePermissions: "author" },
        stubs: SHARED_STUBS,
      });
      await flushPromises(wrapper);
      const row = { id: 42, component_id: 29, rule_id: 7 };
      // Stub + restore via vi (the old delete-window.location hack leaked a
      // plain-object location to every later test in this worker).
      vi.stubGlobal("location", { href: "" });
      wrapper.vm.openTriageFor(row);
      expect(globalThis.location.href).toContain("/components/29/triage?comment=42");
      vi.unstubAllGlobals();
    });
  });

  describe("bulk triage selection", () => {
    const mountAuthor = () =>
      mount(ComponentComments, {
        propsData: { componentId: 42 },
        provide: { effectivePermissions: "author" },
        stubs: SHARED_STUBS,
      });

    beforeEach(() => {
      bulkTriageReviews.mockClear();
      bulkTriageReviews.mockResolvedValue({ data: {} });
    });

    it("select-all toggles only non-adjudicated visible rows", async () => {
      const wrapper = mountAuthor();
      await flushPromises();
      wrapper.vm.rows = [
        { id: 1, adjudicated_at: null },
        { id: 2, adjudicated_at: "2026-05-01T00:00:00Z" },
        { id: 3, adjudicated_at: null },
      ];
      wrapper.vm.toggleSelectAllVisible(true);
      expect(wrapper.vm.selectedIds).toEqual([1, 3]);

      wrapper.vm.toggleSelectAllVisible(false);
      expect(wrapper.vm.selectedIds).toEqual([]);
    });

    it("onToggleSelect adds then removes an id", async () => {
      const wrapper = mountAuthor();
      await flushPromises();
      wrapper.vm.onToggleSelect(7);
      expect(wrapper.vm.selectedIds).toEqual([7]);
      wrapper.vm.onToggleSelect(7);
      expect(wrapper.vm.selectedIds).toEqual([]);
    });

    it("applyBulkTriage sends the selection + payload, then clears it", async () => {
      const wrapper = mountAuthor();
      await flushPromises();
      wrapper.vm.selectedIds = [4, 5];

      await wrapper.vm.applyBulkTriage({ triage_status: "informational", response_comment: null });

      expect(bulkTriageReviews).toHaveBeenCalledWith([4, 5], {
        triage_status: "informational",
        response_comment: null,
      });
      expect(wrapper.vm.selectedIds).toEqual([]);
    });
  });

  // ── v2-6gq.4: b-alert migration ─────────────────────────────────────

  describe("satisfied-by-parent notice uses b-alert", () => {
    it("renders a b-alert (not a raw div.alert) for the parent redirect notice", async () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        stubs: SHARED_STUBS,
      });
      await flushPromises(wrapper);
      wrapper.vm.filterRuleId = 100;
      wrapper.vm.filterParentRuleId = 200;
      wrapper.vm.filterParentDisplayName = "PARENT-001";
      wrapper.vm.rows = [];
      await wrapper.vm.$nextTick();

      const alert = wrapper.findComponent({ name: "BAlert" });
      expect(alert.exists()).toBe(true);
      expect(alert.props("variant")).toBe("info");
      expect(alert.props("show")).toBe(true);
    });
  });

  // ── v2-0re.13.4: composable contracts ───────────────────────────────
  // REQUIREMENTS: permissions arrive via provide/inject (usePermissions),
  // dates render via useDateFormat, and the reply composer state machine
  // flows through useReplyComposer with the onOpen/afterPosted bridge —
  // no non-Alert mixins remain.

  describe("composable contracts (v2-0re.13.4)", () => {
    beforeEach(() => vi.clearAllMocks());

    it("sources permissions from provide via usePermissions — author sees the select column", async () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        provide: { effectivePermissions: "author" },
        stubs: SHARED_STUBS,
      });
      await flushPromises(wrapper);
      expect(usePermissions).toHaveBeenCalled();
      expect(wrapper.vm.fields.map((f) => f.key)).toContain("select");
      expect(wrapper.vm.canTriage).toBe(true);
      expect(wrapper.vm.canMerge).toBe(false);
    });

    it("viewer via provide gets no select column and no triage/merge ability", async () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        provide: { effectivePermissions: "viewer" },
        stubs: SHARED_STUBS,
      });
      await flushPromises(wrapper);
      expect(wrapper.vm.fields.map((f) => f.key)).not.toContain("select");
      expect(wrapper.vm.canTriage).toBe(false);
      expect(wrapper.vm.canMerge).toBe(false);
    });

    it("admin via provide can merge", async () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        provide: { effectivePermissions: "admin" },
        stubs: SHARED_STUBS,
      });
      await flushPromises(wrapper);
      expect(wrapper.vm.canMerge).toBe(true);
    });

    it("renders posted dates via useDateFormat", async () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        provide: { effectivePermissions: "viewer" },
        stubs: SHARED_STUBS,
      });
      await flushPromises(wrapper);
      expect(useDateFormat).toHaveBeenCalled();
      expect(typeof wrapper.vm.friendlyDateTime).toBe("function");
      // moment "lll" format renders the month name, never the raw ISO string
      expect(wrapper.vm.friendlyDateTime("2026-04-27T10:00:00Z")).toContain("Apr");
    });

    it("wires useReplyComposer — reply from a row sets state and shows the modal via the bridge", async () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        provide: { effectivePermissions: "author" },
        stubs: SHARED_STUBS,
      });
      await flushPromises(wrapper);
      expect(useReplyComposer).toHaveBeenCalled();

      const showSpy = vi.spyOn(wrapper.vm.$bvModal, "show").mockImplementation(() => {});
      wrapper.vm.openReplyComposerFromRow({
        id: 142,
        rule_id: 7,
        component_id: 42,
        rule_displayed_name: "CRI-O-000050",
      });
      expect(wrapper.vm.composerState.mode).toBe("reply");
      expect(wrapper.vm.composerState.reviewId).toBe(142);
      expect(wrapper.vm.composerActive).toBe(true);
      await wrapper.vm.$nextTick();
      expect(showSpy).toHaveBeenCalledWith("comment-composer-modal");
    });

    it("afterPosted bridge refreshes the queue when the composer posts", async () => {
      const wrapper = mount(ComponentComments, {
        propsData: { componentId: 42 },
        provide: { effectivePermissions: "author" },
        stubs: SHARED_STUBS,
      });
      await flushPromises(wrapper);
      getComments.mockClear();

      wrapper.vm.openComponentComposerLocal();
      wrapper.vm.onComposerPosted();
      await flushPromises(wrapper);

      expect(getComments).toHaveBeenCalledTimes(1);
      expect(wrapper.vm.composerActive).toBe(false);
    });
  });
});
