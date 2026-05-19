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
    comment: "The check text mentions runc 1.0",
    triage_status: "pending",
    created_at: "2026-05-01T00:00:00Z",
    adjudicated_at: null,
    updated_at: "2026-05-01T00:00:00Z",
    rule_content: ruleContent1,
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

  // ── TriageQueueNav integration ─────────────────────────────────────

  it("renders TriageQueueNav with rows and currentId", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    const nav = w.findComponent({ name: "TriageQueueNav" });
    expect(nav.exists()).toBe(true);
    expect(nav.props("currentId")).toBe(1);
    expect(nav.props("comments")).toHaveLength(3);
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

  // ── Exit when active comment filtered out ──────────────────────────

  it("emits exit when active comment is removed from rows", async () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    await w.setProps({ rows: rows.filter((r) => r.id !== 1) });
    await w.vm.$nextTick();
    expect(w.emitted("exit")).toBeTruthy();
  });

  // ── Cancel emits exit ──────────────────────────────────────────────

  it("emits exit on cancel", () => {
    const w = mount(TriageSplitView, { localVue, propsData: baseProps() });
    w.vm.onCancel();
    expect(w.emitted("exit")).toBeTruthy();
  });

  // ── sortedRows: queue nav matches table id-ascending order ─────────

  it("sorts rows by id ascending so queue position matches table order", () => {
    const reversed = [...rows].reverse();
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps({ rows: reversed, initialCommentId: 1 }),
    });
    expect(w.vm.sortedRows[0].id).toBe(1);
    expect(w.vm.sortedRows[1].id).toBe(2);
    expect(w.vm.sortedRows[2].id).toBe(3);
    const nav = w.findComponent({ name: "TriageQueueNav" });
    expect(nav.props("comments")[0].id).toBe(1);
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

  it("renders admin sidebar when adminPanelOpen prop is true", () => {
    const w = mount(TriageSplitView, {
      localVue,
      propsData: baseProps({ adminPanelOpen: true }),
    });
    expect(w.find("#sidebar-admin-actions").exists()).toBe(true);
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
});
