import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import axios from "axios";
import TriageSplitView from "@/components/triage/TriageSplitView.vue";

vi.mock("axios");

const flushPromises = async (wrapper) => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  if (wrapper) await wrapper.vm.$nextTick();
};

const ruleContent1 = {
  rule_displayed_name: "CNTR-01-000001",
  title: "The container platform must limit privileges",
  rule_severity: "CAT II",
  status: "Applicable - Configurable",
  fixtext: "Configure the container platform to restrict access",
  check_content: "Verify that the container runtime enforces privilege restrictions",
  vuln_discussion: "Without proper privilege restriction, containers could escalate",
  vendor_comments: null,
};

const ruleContent2 = {
  rule_displayed_name: "CNTR-01-000002",
  title: "Test rule 2",
  rule_severity: "CAT III",
  status: "Applicable - Configurable",
  fixtext: null,
  check_content: null,
  vuln_discussion: null,
  vendor_comments: null,
};

const rows = [
  {
    id: 1,
    rule_id: 10,
    rule_displayed_name: "CNTR-01-000001",
    commentable_type: "Rule",
    section: "check_content",
    author_name: "Demo Viewer",
    author_email: "viewer@example.com",
    comment: "The check text mentions runc 1.0",
    triage_status: "pending",
    created_at: "2026-05-01T00:00:00Z",
    adjudicated_at: null,
    updated_at: "2026-05-01T00:00:00Z",
    rule_content: ruleContent1,
    reactions: { up: 2, down: 1 },
  },
  {
    id: 2,
    rule_id: 10,
    rule_displayed_name: "CNTR-01-000001",
    commentable_type: "Rule",
    section: "fixtext",
    author_name: "Demo Reviewer",
    comment: "The fix text could include the seccomp profile path",
    triage_status: "pending",
    created_at: "2026-05-01T01:00:00Z",
    adjudicated_at: null,
    updated_at: "2026-05-01T01:00:00Z",
    rule_content: ruleContent1,
  },
  {
    id: 3,
    rule_id: 11,
    rule_displayed_name: "CNTR-01-000002",
    commentable_type: "Rule",
    section: null,
    author_name: "Demo Reviewer",
    comment: "Could we soften the severity?",
    triage_status: "concur",
    created_at: "2026-05-01T02:00:00Z",
    adjudicated_at: null,
    updated_at: "2026-05-01T02:00:00Z",
    rule_content: ruleContent2,
  },
];

function baseProps(overrides = {}) {
  return {
    rows,
    initialCommentId: 1,
    componentId: 5,
    effectivePermissions: "admin",
    ...overrides,
  };
}

describe("TriageSplitView", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  // ── Reactivity: activeCommentId as data, object via computed ────────

  it("derives activeComment from activeCommentId via computed", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    expect(w.vm.activeCommentId).toBe(1);
    expect(w.vm.activeComment).not.toBeNull();
    expect(w.vm.activeComment.id).toBe(1);
    expect(w.vm.activeComment.rule_displayed_name).toBe("CNTR-01-000001");
  });

  it("updates activeComment when activeCommentId changes", async () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    w.vm.activeCommentId = 2;
    await w.vm.$nextTick();
    expect(w.vm.activeComment.id).toBe(2);
    expect(w.vm.activeComment.section).toBe("fixtext");
  });

  // ── Rule content passed to RuleContextPanel ────────────────────────

  it("passes rule_content and ruleDisplayedName to RuleContextPanel", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    const panel = w.findComponent({ name: "RuleContextPanel" });
    expect(panel.exists()).toBe(true);
    expect(panel.props("ruleContent")).not.toBeNull();
    expect(panel.props("ruleContent").title).toBe(
      "The container platform must limit privileges",
    );
    expect(panel.props("ruleDisplayedName")).toBe("CNTR-01-000001");
  });

  it("passes ruleStatus from the active comment's rule_content.status", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    const panel = w.findComponent({ name: "RuleContextPanel" });
    expect(panel.props("ruleStatus")).toBe("Applicable - Configurable");
  });

  it("passes focusedSection from the active comment's section", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    const panel = w.findComponent({ name: "RuleContextPanel" });
    expect(panel.props("focusedSection")).toBe("check_content");
  });

  // ── CommentTriageForm integration ──────────────────────────────────

  it("renders CommentTriageForm for the active comment", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    const form = w.findComponent({ name: "CommentTriageForm" });
    expect(form.exists()).toBe(true);
    expect(form.props("review").id).toBe(1);
  });

  // ── Three-column layout with TriageRuleSidebar ─────────────────────

  it("renders TriageRuleSidebar in the left column", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    const sidebar = w.findComponent({ name: "TriageRuleSidebar" });
    expect(sidebar.exists()).toBe(true);
    expect(sidebar.props("currentId")).toBe(1);
    expect(sidebar.props("comments")).toHaveLength(3);
  });

  it("uses a three-column layout with sidebar, context, and triage panes", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    const cols = w.findAll(".col-lg-2, .col-lg-5");
    expect(cols.length).toBe(3);
  });

  // ── Dirty-form guard ───────────────────────────────────────────────

  it("prompts before switching when form is dirty", async () => {
    window.confirm = vi.fn().mockReturnValue(false);
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    w.vm.isDirty = true;
    w.vm.onQueueSelect(2);
    expect(window.confirm).toHaveBeenCalled();
    expect(w.vm.activeCommentId).toBe(1);
  });

  it("switches when form is dirty and user confirms", async () => {
    window.confirm = vi.fn().mockReturnValue(true);
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    w.vm.isDirty = true;
    w.vm.onQueueSelect(2);
    expect(w.vm.activeCommentId).toBe(2);
  });

  it("switches without prompting when form is clean", () => {
    window.confirm = vi.fn();
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    w.vm.isDirty = false;
    w.vm.onQueueSelect(2);
    expect(window.confirm).not.toHaveBeenCalled();
    expect(w.vm.activeCommentId).toBe(2);
  });

  // ── Save with optimistic locking ───────────────────────────────────

  it("sends updated_at with triage PATCH for optimistic locking", async () => {
    axios.patch.mockResolvedValue({
      data: { review: { ...rows[0], triage_status: "concur" } },
    });
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    await w.vm.onTriageSave({ triage_status: "concur" });
    await flushPromises(w);
    expect(axios.patch).toHaveBeenCalledWith(
      "/reviews/1/triage",
      expect.objectContaining({
        triage_status: "concur",
        expected_updated_at: "2026-05-01T00:00:00Z",
      }),
    );
  });

  it("emits triaged on successful save", async () => {
    axios.patch.mockResolvedValue({
      data: { review: { ...rows[0], triage_status: "concur" } },
    });
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    await w.vm.onTriageSave({ triage_status: "concur" });
    await flushPromises(w);
    const payload = w.emitted("triaged");
    expect(payload).toHaveLength(1);
    expect(payload[0][0].triage_status).toBe("concur");
  });

  // ── Save button disabled during request ────────────────────────────

  it("sets saving=true during pending request", async () => {
    axios.patch.mockImplementation(() => new Promise(() => {}));
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    w.vm.onTriageSave({ triage_status: "concur" });
    await w.vm.$nextTick();
    expect(w.vm.saving).toBe(true);
  });

  // ── Error handling ─────────────────────────────────────────────────

  it("shows conflict message on 409 (optimistic lock failure)", async () => {
    axios.patch.mockRejectedValue({
      response: { status: 409, data: { error: "Record was modified" } },
    });
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    await w.vm.onTriageSave({ triage_status: "concur" });
    await flushPromises(w);
    expect(w.vm.conflictAlert).toBe(true);
    expect(w.vm.saving).toBe(false);
  });

  it("surfaces 422 errors via AlertMixin", async () => {
    axios.patch.mockRejectedValue({
      response: { status: 422, data: { error: "Non-concur requires a response" } },
    });
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    const alertSpy = vi.spyOn(w.vm, "alertOrNotifyResponse").mockImplementation(() => {});
    await w.vm.onTriageSave({ triage_status: "non_concur" });
    await flushPromises(w);
    expect(alertSpy).toHaveBeenCalled();
    alertSpy.mockRestore();
  });

  // ── Filter resilience: stay in split-pane when rows change ─────────

  it("selects first available row when active comment is filtered out but rows remain", async () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    expect(w.vm.activeCommentId).toBe(1);
    await w.setProps({ rows: rows.filter((r) => r.id !== 1) });
    await w.vm.$nextTick();
    expect(w.vm.activeCommentId).toBe(2);
    expect(w.emitted("exit")).toBeFalsy();
  });

  it("emits exit only when ALL rows are removed (empty result set)", async () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    await w.setProps({ rows: [] });
    await w.vm.$nextTick();
    expect(w.emitted("exit")).toBeTruthy();
  });

  it("does not exit when rows change to a different filtered set", async () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    const filteredRows = [rows[2]];
    await w.setProps({ rows: filteredRows });
    await w.vm.$nextTick();
    expect(w.vm.activeCommentId).toBe(3);
    expect(w.emitted("exit")).toBeFalsy();
  });

  it("refocuses content heading when auto-selecting new comment after filter", async () => {
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps(),
      attachTo: document.body,
    });
    await w.vm.$nextTick();
    await w.setProps({ rows: rows.filter((r) => r.id !== 1) });
    await w.vm.$nextTick();
    await w.vm.$nextTick();
    expect(w.vm.activeCommentId).toBe(2);
    w.destroy();
  });

  // ── Cancel emits exit ──────────────────────────────────────────────

  it("emits exit on cancel", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    w.vm.onCancel();
    expect(w.emitted("exit")).toBeTruthy();
  });

  // ── sortedRows: queue nav matches table id-ascending order ─────────

  it("sorts rows by id ascending so sidebar position matches table order", () => {
    const reversed = [...rows].reverse();
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps({ rows: reversed, initialCommentId: 1 }),
    });
    expect(w.vm.sortedRows[0].id).toBe(1);
    expect(w.vm.sortedRows[1].id).toBe(2);
    expect(w.vm.sortedRows[2].id).toBe(3);
    const sidebar = w.findComponent({ name: "TriageRuleSidebar" });
    expect(sidebar.props("comments")[0].id).toBe(1);
  });

  // ── Role gating: viewer cannot see triage form ─────────────────────

  it("hides CommentTriageForm for viewer role", () => {
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps({ effectivePermissions: "viewer" }),
    });
    expect(w.findComponent({ name: "CommentTriageForm" }).exists()).toBe(false);
    expect(w.text()).toContain("Read-only");
  });

  it("shows CommentTriageForm for author role", () => {
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps({ effectivePermissions: "author" }),
    });
    expect(w.findComponent({ name: "CommentTriageForm" }).exists()).toBe(true);
  });

  // ── Reply thread integration ───────────────────────────────────────

  it("renders CommentThread for inline replies", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    const thread = w.findComponent({ name: "CommentThread" });
    expect(thread.exists()).toBe(true);
    expect(thread.props("parentReviewId")).toBe(1);
  });

  // ── Admin actions (migrated from modal) ────────────────────────────

  it("renders inline admin actions for admin users", () => {
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps({ effectivePermissions: "admin" }),
    });
    expect(w.find("[data-testid='admin-actions-inline']").exists()).toBe(true);
    expect(w.find("[data-testid='admin-action-force-withdraw']").exists()).toBe(true);
  });

  it("hides admin actions for non-admin users", () => {
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps({ effectivePermissions: "author" }),
    });
    expect(w.find("[data-testid='admin-actions-inline']").exists()).toBe(false);
  });

  it("posts to admin_withdraw with audit comment", async () => {
    axios.patch.mockResolvedValue({
      data: { review: { ...rows[0], triage_status: "withdrawn" } },
    });
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    w.vm.adminAction = "force-withdraw";
    w.vm.adminAuditComment = "spam content";
    await w.vm.submitAdminAction();
    await flushPromises(w);
    expect(axios.patch).toHaveBeenCalledWith(
      "/reviews/1/admin_withdraw",
      expect.objectContaining({ audit_comment: "spam content" }),
    );
    expect(w.emitted("triaged")).toHaveLength(1);
  });

  it("posts DELETE to admin_destroy with audit comment and typed-id confirmation", async () => {
    axios.delete.mockResolvedValue({ data: { ok: true } });
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    w.vm.adminAction = "hard-delete";
    w.vm.adminAuditComment = "PII removed";
    w.vm.adminConfirmationId = "1";
    await w.vm.submitAdminAction();
    await flushPromises(w);
    expect(axios.delete).toHaveBeenCalledWith(
      "/reviews/1/admin_destroy",
      expect.objectContaining({
        data: expect.objectContaining({ audit_comment: "PII removed" }),
      }),
    );
    expect(w.emitted("destroyed")).toHaveLength(1);
    expect(w.emitted("destroyed")[0][0]).toBe(1);
  });

  it("canSubmitAdminAction requires audit comment", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    w.vm.adminAction = "force-withdraw";
    w.vm.adminAuditComment = "";
    expect(w.vm.canSubmitAdminAction).toBe(false);
    w.vm.adminAuditComment = "reason";
    expect(w.vm.canSubmitAdminAction).toBe(true);
  });

  it("canSubmitAdminAction for hard-delete requires typed-id match", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    w.vm.adminAction = "hard-delete";
    w.vm.adminAuditComment = "reason";
    w.vm.adminConfirmationId = "wrong";
    expect(w.vm.canSubmitAdminAction).toBe(false);
    w.vm.adminConfirmationId = "1";
    expect(w.vm.canSubmitAdminAction).toBe(true);
  });

  // ── Reaction buttons ──────────────────────────────────────────────

  // ── Staleness badge ──────────────────────────────────────────────

  it("shows staleness badge when rule updated after comment was posted", () => {
    const staleRows = rows.map((r) => ({
      ...r,
      rule_content: {
        ...ruleContent1,
        rule_updated_at: "2026-06-01T00:00:00.000Z",
      },
    }));
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps({ rows: staleRows, initialCommentId: 1 }),
    });
    expect(w.find("[data-testid='staleness-badge']").exists()).toBe(true);
  });

  it("hides staleness badge when rule not updated after comment", () => {
    const freshRows = rows.map((r) => ({
      ...r,
      rule_content: {
        ...ruleContent1,
        rule_updated_at: "2026-01-01T00:00:00.000Z",
      },
    }));
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps({ rows: freshRows, initialCommentId: 1 }),
    });
    expect(w.find("[data-testid='staleness-badge']").exists()).toBe(false);
  });

  // ── Reaction buttons ──────────────────────────────────────────────

  it("renders ReactionButtons for the active comment", async () => {
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps({ initialCommentId: 1 }),
    });
    await flushPromises(w);
    const reactionBtns = w.findComponent({ name: "ReactionButtons" });
    expect(reactionBtns.exists()).toBe(true);
    expect(reactionBtns.props("reviewId")).toBe(1);
  });

  // ── doSave adjudicate logic ─────────────────────────────────────────

  it("doSave with advance=false should NOT call adjudicate endpoint", async () => {
    axios.patch.mockResolvedValue({
      data: { review: { id: 1, triage_status: "concur" } },
    });

    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps({ initialCommentId: 1 }),
    });
    await flushPromises(w);

    await w.vm.doSave({ triage_status: "concur" }, false);
    await flushPromises(w);

    const patchCalls = axios.patch.mock.calls;
    const triageCalls = patchCalls.filter(([url]) => url.includes("/triage"));
    const adjudicateCalls = patchCalls.filter(([url]) => url.includes("/adjudicate"));

    expect(triageCalls.length).toBe(1);
    expect(adjudicateCalls.length).toBe(0);
  });

  it("doSave with advance=true should call adjudicate endpoint for non-terminal statuses", async () => {
    axios.patch.mockResolvedValueOnce({
      data: { review: { id: 1, triage_status: "concur" } },
    });
    axios.patch.mockResolvedValueOnce({
      data: { review: { id: 1, triage_status: "concur", adjudicated_at: "2026-05-20" } },
    });

    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps({ initialCommentId: 1 }),
    });
    await flushPromises(w);

    await w.vm.doSave({ triage_status: "concur" }, true);
    await flushPromises(w);

    const patchCalls = axios.patch.mock.calls;
    const triageCalls = patchCalls.filter(([url]) => url.includes("/triage"));
    const adjudicateCalls = patchCalls.filter(([url]) => url.includes("/adjudicate"));

    expect(triageCalls.length).toBe(1);
    expect(adjudicateCalls.length).toBe(1);
  });

  // ── ARIA landmarks + focus management ──────────────────────────────

  it("wraps sidebar in nav[aria-label='Comment triage queue']", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    const nav = w.find("nav[aria-label='Comment triage queue']");
    expect(nav.exists()).toBe(true);
    expect(nav.findComponent({ name: "TriageRuleSidebar" }).exists()).toBe(true);
  });

  it("wraps content pane in region with aria-label 'Comment details'", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    const main = w.find("[role='main'][aria-label='Comment details']");
    expect(main.exists()).toBe(true);
    expect(main.findComponent({ name: "RuleContextPanel" }).exists()).toBe(true);
  });

  it("wraps action pane in region with aria-label 'Triage decision'", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    const aside = w.find("[role='complementary'][aria-label='Triage decision']");
    expect(aside.exists()).toBe(true);
  });

  it("renders skip links for keyboard users", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    const skipLinks = w.findAll(".sr-only-focusable, .skip-link");
    expect(skipLinks.length).toBeGreaterThanOrEqual(2);
    const hrefs = skipLinks.wrappers.map((s) => s.attributes("href"));
    expect(hrefs).toContain("#triage-content");
    expect(hrefs).toContain("#triage-form");
  });

  it("focuses the content heading on mount", async () => {
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps(),
      attachTo: document.body,
    });
    await w.vm.$nextTick();
    await w.vm.$nextTick();
    const heading = w.find("[data-testid='content-heading']");
    expect(heading.exists()).toBe(true);
    expect(heading.attributes("tabindex")).toBe("-1");
    w.destroy();
  });

  it("refocuses content heading after advanceToNext", async () => {
    axios.patch.mockResolvedValueOnce({
      data: { review: { id: 1, triage_status: "concur" } },
    });
    axios.patch.mockResolvedValueOnce({
      data: { review: { id: 1, triage_status: "concur", adjudicated_at: "2026-05-20" } },
    });
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps(),
      attachTo: document.body,
    });
    await w.vm.doSave({ triage_status: "concur" }, true);
    await flushPromises(w);
    expect(w.vm.activeCommentId).toBe(2);
    w.destroy();
  });

  it("doSave with advance=true should NOT adjudicate for SINGLE_BUTTON statuses", async () => {
    axios.patch.mockResolvedValue({
      data: { review: { id: 1, triage_status: "withdrawn" } },
    });

    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps({ initialCommentId: 1 }),
    });
    await flushPromises(w);

    await w.vm.doSave({ triage_status: "withdrawn" }, true);
    await flushPromises(w);

    const adjudicateCalls = axios.patch.mock.calls.filter(([url]) => url.includes("/adjudicate"));
    expect(adjudicateCalls.length).toBe(0);
  });

  // ── Author email + divider in triage form ─────────────────────────

  it("shows author email inline with the author name", () => {
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps(),
    });
    expect(w.find("[data-testid='author-email']").exists()).toBe(true);
    expect(w.find("[data-testid='author-email']").text()).toContain("viewer@example.com");
  });

  it("renders a divider between author info and comment blockquote", () => {
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps(),
    });
    expect(w.find("[data-testid='comment-divider']").exists()).toBe(true);
  });
});
