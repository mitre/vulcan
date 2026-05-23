import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CommentTriageForm from "@/components/triage/CommentTriageForm.vue";

const sampleReview = {
  id: 142,
  rule_id: 7,
  rule_displayed_name: "CRI-O-000050",
  section: "check_content",
  comment: "Check text mentions runc 1.0...",
  triage_status: "pending",
  created_at: "2026-04-27T10:00:00Z",
  component_id: 5,
};

function baseProps(overrides = {}) {
  return {
    review: sampleReview,
    componentId: 5,
    loading: false,
    ...overrides,
  };
}

describe("CommentTriageForm", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  // ── Rendering ──────────────────────────────────────────────────────

  it("renders all 7 decision radio buttons", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    const radios = w.findAll('input[type="radio"][name="triage"]');
    expect(radios.length).toBe(7);
  });

  it("renders response textarea", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    expect(w.find("textarea").exists()).toBe(true);
  });

  it("renders Save and Cancel buttons", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    expect(w.find('[data-testid="cancel"]').exists()).toBe(true);
    expect(w.find('[data-testid="save-and-next"]').exists()).toBe(true);
  });

  // ── Validation ─────────────────────────────────────────────────────

  it("canSave is false when no status is selected", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    expect(w.vm.canSave).toBe(false);
  });

  it("canSave is false when non_concur is selected with empty response", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "non_concur";
    w.vm.responseComment = "";
    expect(w.vm.canSave).toBe(false);
  });

  it("canSave is true when non_concur is selected with a response", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "non_concur";
    w.vm.responseComment = "we addressed differently";
    expect(w.vm.canSave).toBe(true);
  });

  it("canSave is false when duplicate is selected without a duplicate target", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "duplicate";
    w.vm.duplicateOfId = null;
    expect(w.vm.canSave).toBe(false);
  });

  it("canSave is true when duplicate is selected with a target", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "duplicate";
    w.vm.duplicateOfId = 99;
    expect(w.vm.canSave).toBe(true);
  });

  it("responseState returns false (invalid) when non_concur + empty response", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "non_concur";
    w.vm.responseComment = "";
    expect(w.vm.responseState).toBe(false);
  });

  // ── Single-button vs two-button footer ─────────────────────────────

  it("shows 'Save decision' button only for non-single-button statuses (concur, concur_with_comment, non_concur)", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    ["concur", "concur_with_comment", "non_concur"].forEach((status) => {
      w.vm.triageStatus = status;
      expect(w.vm.hasSaveDecisionOnlyOption).toBe(true);
    });
  });

  it("hides 'Save decision' for single-button statuses (terminal + needs_clarification)", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    ["informational", "duplicate", "needs_clarification", "withdrawn", "addressed_by"].forEach((status) => {
      w.vm.triageStatus = status;
      expect(w.vm.hasSaveDecisionOnlyOption).toBe(false);
    });
  });

  it("labels primary button 'Save & wait for commenter' for needs_clarification", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "needs_clarification";
    expect(w.vm.primaryButtonLabel).toBe("Save & wait for commenter");
  });

  it("labels primary button 'Save & next' by default", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "concur";
    expect(w.vm.primaryButtonLabel).toBe("Save & next");
  });

  // ── Events ─────────────────────────────────────────────────────────

  it("emits save with decision payload on Save decision click", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "concur";
    w.vm.responseComment = "thanks";
    await w.vm.$nextTick();
    await w.find('[data-testid="save-decision"]').trigger("click");
    expect(w.emitted("save")).toBeTruthy();
    const payload = w.emitted("save")[0][0];
    expect(payload.triage_status).toBe("concur");
    expect(payload.response_comment).toBe("thanks");
  });

  it("emits save-and-next with decision payload on primary button click", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "concur";
    await w.vm.$nextTick();
    await w.find('[data-testid="save-and-next"]').trigger("click");
    expect(w.emitted("save-and-next")).toBeTruthy();
    const payload = w.emitted("save-and-next")[0][0];
    expect(payload.triage_status).toBe("concur");
  });

  it("emits cancel on Cancel click", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    await w.find('[data-testid="cancel"]').trigger("click");
    expect(w.emitted("cancel")).toBeTruthy();
  });

  it("emits dirty(true) when triageStatus changes from initial", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "concur";
    await w.vm.$nextTick();
    expect(w.emitted("dirty")).toBeTruthy();
    expect(w.emitted("dirty")[0][0]).toBe(true);
  });

  it("emits dirty(true) when responseComment changes", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.responseComment = "new response";
    await w.vm.$nextTick();
    const dirtyEvents = w.emitted("dirty");
    expect(dirtyEvents).toBeTruthy();
    expect(dirtyEvents[dirtyEvents.length - 1][0]).toBe(true);
  });

  // ── Save blocked when canSave is false ─────────────────────────────

  it("does not emit save when canSave is false", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    // triageStatus is null → canSave is false
    await w.find('[data-testid="save-and-next"]').trigger("click");
    expect(w.emitted("save-and-next")).toBeFalsy();
  });

  // ── Loading state ──────────────────────────────────────────────────

  it("disables buttons when loading prop is true", () => {
    const w = mount(CommentTriageForm, {
      localVue,
      propsData: baseProps({ loading: true }),
    });
    w.vm.triageStatus = "concur";
    expect(w.find('[data-testid="save-and-next"]').attributes("disabled")).toBeTruthy();
  });

  // ── Review watcher resets form ─────────────────────────────────────

  it("resets form state when review prop changes", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "concur";
    w.vm.responseComment = "old response";

    await w.setProps({
      review: { ...sampleReview, id: 200, triage_status: "pending" },
    });
    expect(w.vm.triageStatus).toBe(null);
    expect(w.vm.responseComment).toBe("");
  });

  it("seeds triageStatus from review when review has a non-pending status", async () => {
    const w = mount(CommentTriageForm, {
      localVue,
      propsData: baseProps({
        review: { ...sampleReview, triage_status: "concur" },
      }),
    });
    expect(w.vm.triageStatus).toBe("concur");
  });

  // ── Decision payload includes duplicate_of_review_id when applicable ──

  it("includes duplicate_of_review_id in payload when status is duplicate", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "duplicate";
    w.vm.duplicateOfId = 77;
    await w.vm.$nextTick();
    await w.find('[data-testid="save-and-next"]').trigger("click");
    const payload = w.emitted("save-and-next")[0][0];
    expect(payload.duplicate_of_review_id).toBe(77);
  });

  it("does NOT include duplicate_of_review_id for non-duplicate statuses", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "concur";
    await w.vm.$nextTick();
    await w.find('[data-testid="save-and-next"]').trigger("click");
    const payload = w.emitted("save-and-next")[0][0];
    expect(payload.duplicate_of_review_id).toBeUndefined();
  });

  // ── addressed_by status ──────────────────────────────────────────────

  it("shows RulePicker when addressed_by is selected", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "addressed_by";
    await w.vm.$nextTick();
    expect(w.findComponent({ name: "RulePicker" }).exists()).toBe(true);
  });

  it("canSave is false when addressed_by is selected without a rule", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "addressed_by";
    w.vm.addressedByRuleId = null;
    expect(w.vm.canSave).toBe(false);
  });

  it("canSave is true when addressed_by is selected with a rule", () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "addressed_by";
    w.vm.addressedByRuleId = 42;
    expect(w.vm.canSave).toBe(true);
  });

  it("includes addressed_by_rule_id in payload when status is addressed_by", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "addressed_by";
    w.vm.addressedByRuleId = 42;
    await w.vm.$nextTick();
    await w.find('[data-testid="save-and-next"]').trigger("click");
    const payload = w.emitted("save-and-next")[0][0];
    expect(payload.addressed_by_rule_id).toBe(42);
  });

  it("does NOT include addressed_by_rule_id for non-addressed_by statuses", async () => {
    const w = mount(CommentTriageForm, { localVue, propsData: baseProps() });
    w.vm.triageStatus = "concur";
    await w.vm.$nextTick();
    await w.find('[data-testid="save-and-next"]').trigger("click");
    const payload = w.emitted("save-and-next")[0][0];
    expect(payload.addressed_by_rule_id).toBeUndefined();
  });

  it("seeds addressedByRuleId from review when restoring an addressed_by triage", () => {
    const w = mount(CommentTriageForm, {
      localVue,
      propsData: baseProps({
        review: { ...sampleReview, triage_status: "addressed_by", addressed_by_rule_id: 99 },
      }),
    });
    expect(w.vm.triageStatus).toBe("addressed_by");
    expect(w.vm.addressedByRuleId).toBe(99);
  });
});
