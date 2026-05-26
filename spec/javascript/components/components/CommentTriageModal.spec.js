import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CommentTriageModal from "@/components/components/CommentTriageModal.vue";
import { submitTriage, submitAdjudicate, submitAdminAction } from "@/services/triageService";
import { updateSection } from "@/api/reviewsApi";

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

vi.mock("@/services/triageService", () => ({
  submitTriage: vi.fn(() => Promise.resolve({ data: {} })),
  submitAdjudicate: vi.fn(() => Promise.resolve({ data: {} })),
  submitAdminAction: vi.fn(() => Promise.resolve({ data: {} })),
}));

vi.mock("@/api/reviewsApi", () => ({
  updateSection: vi.fn(() => Promise.resolve({ data: {} })),
}));

const flushPromises = async (wrapper) => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  if (wrapper) await wrapper.vm.$nextTick();
};

// b-modal in BootstrapVue renders to a portal and stays empty until shown,
// so for body-content assertions we stub it with a div that always renders
// its default + modal-footer slots. Same pattern as ConfirmDeleteModal.spec.js.
// `centered` is exposed so we can assert vertical-centering at the template
// level (Aaron 2026-04-29 — visual parity with CommentComposerModal).
const visibleModalStub = {
  "b-modal": {
    template: `
      <div class="modal" :data-centered="String(centered)">
        <div class="modal-body"><slot></slot></div>
        <div class="modal-footer"><slot name="modal-footer" :cancel="() => {}"></slot></div>
      </div>
    `,
    props: {
      title: String,
      centered: { type: Boolean, default: false },
    },
  },
};

const sampleReview = {
  id: 142,
  rule_id: 7,
  rule_displayed_name: "CRI-O-000050",
  section: "check_content",
  author_name: "John Doe",
  author_email: "john@redhat.com",
  comment: "Check text mentions runc 1.0...",
  created_at: "2026-04-27T10:00:00Z",
  triage_status: "pending",
  adjudicated_at: null,
};

describe("CommentTriageModal", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("renders the comment + section context", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
      stubs: visibleModalStub,
    });
    const html = w.html();
    expect(html).toContain("CRI-O-000050");
    expect(html).toContain("Check"); // friendly section label via SectionLabel
    expect(html).toContain("John Doe");
  });

  it("shows decision radios with friendly label + DISA term in parens (the pedagogical exception)", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
      stubs: visibleModalStub,
    });
    const html = w.html();
    expect(html).toMatch(/Accept[^<]*Concur\)/);
    expect(html).toMatch(/Decline[^<]*Non-concur\)/);
  });

  it("embeds CommentTriageForm with non_concur validation delegated to the form", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
      stubs: visibleModalStub,
    });
    const form = w.findComponent({ name: "CommentTriageForm" });
    expect(form.exists()).toBe(true);
    form.vm.triageStatus = "non_concur";
    form.vm.responseComment = "";
    expect(form.vm.canSave).toBe(false);
    form.vm.responseComment = "we already addressed differently";
    expect(form.vm.canSave).toBe(true);
  });

  it("embeds CommentTriageForm with duplicate validation delegated to the form", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
      stubs: visibleModalStub,
    });
    const form = w.findComponent({ name: "CommentTriageForm" });
    form.vm.triageStatus = "duplicate";
    form.vm.duplicateOfId = null;
    expect(form.vm.canSave).toBe(false);
    form.vm.duplicateOfId = 99;
    expect(form.vm.canSave).toBe(true);
  });

  it("calls submitTriage when form emits save", async () => {
    submitTriage.mockResolvedValue({
      data: { review: { ...sampleReview, triage_status: "concur" } },
    });
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    await w.vm.doTriage({ triage_status: "concur", response_comment: "thanks" }, false);
    await flushPromises(w);

    expect(submitTriage).toHaveBeenCalledWith(
      142,
      expect.objectContaining({ triage_status: "concur", response_comment: "thanks" }),
    );
    expect(w.emitted("triaged")).toBeTruthy();
  });

  it("'Save & next' fires triage AND adjudicate for non-terminal statuses", async () => {
    submitTriage.mockResolvedValue({
      data: { review: { ...sampleReview, triage_status: "concur" } },
    });
    submitAdjudicate.mockResolvedValue({
      data: {
        review: { ...sampleReview, triage_status: "concur", adjudicated_at: "2026-04-29T12:00Z" },
      },
    });
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    await w.vm.doTriage({ triage_status: "concur", response_comment: "done" }, true);
    await flushPromises(w);

    expect(submitTriage).toHaveBeenCalledWith(142, expect.objectContaining({ triage_status: "concur" }));
    expect(submitAdjudicate).toHaveBeenCalledWith(142);
    expect(w.emitted("adjudicated")).toBeTruthy();
  });

  it("delegates single-button and label logic to the embedded CommentTriageForm", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
      stubs: visibleModalStub,
    });
    const form = w.findComponent({ name: "CommentTriageForm" });
    expect(form.exists()).toBe(true);
    ["informational", "duplicate", "needs_clarification", "withdrawn"].forEach((status) => {
      form.vm.triageStatus = status;
      expect(form.vm.hasSaveDecisionOnlyOption).toBe(false);
    });
    form.vm.triageStatus = "concur";
    expect(form.vm.hasSaveDecisionOnlyOption).toBe(true);
  });

  it("form uses 'Save & wait for commenter' label for needs_clarification", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
      stubs: visibleModalStub,
    });
    const form = w.findComponent({ name: "CommentTriageForm" });
    form.vm.triageStatus = "needs_clarification";
    expect(form.vm.primaryButtonLabel).toBe("Save & wait for commenter");
    form.vm.triageStatus = "concur";
    expect(form.vm.primaryButtonLabel).toBe("Save & next");
  });

  it("skips the redundant adjudicate call for auto-adjudicating statuses", async () => {
    submitTriage.mockResolvedValue({
      data: { review: { ...sampleReview, triage_status: "informational" } },
    });
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    await w.vm.doTriage({ triage_status: "informational" }, true);
    await flushPromises(w);

    expect(submitTriage).toHaveBeenCalledTimes(1);
    expect(submitAdjudicate).not.toHaveBeenCalled();
    expect(w.emitted("adjudicated")).toBeFalsy();
  });

  it("surfaces server errors via AlertMixin without crashing", async () => {
    submitTriage.mockRejectedValueOnce({ response: { status: 422, data: {} } });
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    const alertSpy = vi.spyOn(w.vm, "alertOrNotifyResponse").mockImplementation(() => {});

    await w.vm.doTriage({ triage_status: "concur" }, false);
    await flushPromises(w);

    expect(alertSpy).toHaveBeenCalled();
    alertSpy.mockRestore();
  });

  // Vertical centering — visual parity with CommentComposerModal,
  // requested by Aaron 2026-04-29.
  it("sets centered=true on the b-modal so it sits in the middle of the viewport", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
      stubs: visibleModalStub,
    });
    expect(w.find(".modal").attributes("data-centered")).toBe("true");
  });

  // ==========================================================================
  // admin force-withdraw + restore actions inside the modal.
  // Visible only when the current user has effective admin permissions.
  // Audit comment is required server-side; UI gates the Confirm button.
  // ==========================================================================
  describe("admin actions disclosure", () => {
    const adjudicatedReview = {
      ...sampleReview,
      triage_status: "withdrawn",
      adjudicated_at: "2026-04-30T10:00:00Z",
    };

    it("hides the Admin actions disclosure when effectivePermissions !== 'admin'", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "author" },
        stubs: visibleModalStub,
      });
      expect(w.html()).not.toContain("Admin actions");
    });

    it("renders the Admin actions disclosure when effectivePermissions === 'admin'", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
        stubs: visibleModalStub,
      });
      expect(w.html()).toContain("Admin actions");
    });

    it("calls submitAdminAction for force-withdraw", async () => {
      submitAdminAction.mockResolvedValue({
        data: { review: { ...sampleReview, triage_status: "withdrawn" } },
      });
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
      });
      vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

      w.vm.adminAction = "force-withdraw";
      w.vm.adminAuditComment = "spam content removed";
      await w.vm.doSubmitAdminAction();
      await flushPromises(w);

      expect(submitAdminAction).toHaveBeenCalledWith(
        142, "force-withdraw", { audit_comment: "spam content removed" },
      );
    });

    it("calls submitAdminAction for restore", async () => {
      submitAdminAction.mockResolvedValue({
        data: { review: { ...adjudicatedReview, triage_status: "pending", adjudicated_at: null } },
      });
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: adjudicatedReview, effectivePermissions: "admin" },
      });
      vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

      w.vm.adminAction = "restore";
      w.vm.adminAuditComment = "withdrew the wrong one";
      await w.vm.doSubmitAdminAction();
      await flushPromises(w);

      expect(submitAdminAction).toHaveBeenCalledWith(
        142, "restore", { audit_comment: "withdrew the wrong one" },
      );
    });

    it("canSubmitAdminAction is false until the audit comment is non-blank", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
      });
      w.vm.adminAction = "force-withdraw";
      w.vm.adminAuditComment = "";
      expect(w.vm.canSubmitAdminAction).toBe(false);
      w.vm.adminAuditComment = "reason";
      expect(w.vm.canSubmitAdminAction).toBe(true);
    });

    it("only offers Restore when the comment is already adjudicated", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
      });
      expect(w.vm.canRestore).toBe(false);

      w.setProps({ review: adjudicatedReview });
      // setProps doesn't always re-fire computed instantly without nextTick
      return w.vm.$nextTick().then(() => {
        expect(w.vm.canRestore).toBe(true);
      });
    });
  });

  // ==========================================================================
  // admin hard-delete (irreversible). Typed-confirmation
  // safeguard: admin must type the review ID into a confirmation field
  // before the Confirm button enables. Audit comment is also required.
  // ==========================================================================
  describe("admin hard-delete", () => {
    it("offers a Hard-delete button when admin actions disclosure is opened", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
        stubs: visibleModalStub,
      });
      expect(w.html()).toContain("Hard-delete");
    });

    it("canSubmitAdminAction stays false until BOTH audit comment AND typed-id confirmation are valid", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
      });
      w.vm.adminAction = "hard-delete";
      w.vm.adminAuditComment = "PII removed";
      w.vm.adminConfirmationId = "";
      expect(w.vm.canSubmitAdminAction).toBe(false);

      w.vm.adminConfirmationId = "wrong-id";
      expect(w.vm.canSubmitAdminAction).toBe(false);

      w.vm.adminConfirmationId = String(sampleReview.id);
      expect(w.vm.canSubmitAdminAction).toBe(true);
    });

    it("calls submitAdminAction for hard-delete", async () => {
      submitAdminAction.mockResolvedValue({ data: { ok: true } });
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
      });
      vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

      w.vm.adminAction = "hard-delete";
      w.vm.adminAuditComment = "PII removed per legal";
      w.vm.adminConfirmationId = String(sampleReview.id);
      await w.vm.doSubmitAdminAction();
      await flushPromises(w);

      expect(submitAdminAction).toHaveBeenCalledWith(
        142, "hard-delete", { audit_comment: "PII removed per legal" },
      );
    });

    it("emits a 'destroyed' event after a successful hard-delete (parent table can remove the row)", async () => {
      submitAdminAction.mockResolvedValue({ data: { ok: true } });
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
      });
      vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

      w.vm.adminAction = "hard-delete";
      w.vm.adminAuditComment = "cleanup";
      w.vm.adminConfirmationId = String(sampleReview.id);
      await w.vm.doSubmitAdminAction();
      await flushPromises(w);

      expect(w.emitted("destroyed")).toBeTruthy();
      expect(w.emitted("destroyed")[0][0]).toBe(sampleReview.id);
    });
  });

  // ==========================================================================
  // admin move-to-rule. Reassigns a misplaced comment
  // (and atomically all its replies via the controller's parent-first walk)
  // to a different rule in the same component. Audit comment required;
  // target rule chosen via the embedded RulePicker.
  // ==========================================================================
  describe("admin move-to-rule", () => {
    it("offers a Move-to-rule button when admin actions disclosure is opened", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
        stubs: visibleModalStub,
      });
      expect(w.html()).toContain("Move to rule");
    });

    it("canSubmitAdminAction stays false until BOTH audit comment AND target rule are set", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
      });
      w.vm.adminAction = "move-to-rule";
      w.vm.adminAuditComment = "wrong rule";
      w.vm.adminTargetRuleId = null;
      expect(w.vm.canSubmitAdminAction).toBe(false);

      w.vm.adminTargetRuleId = 99;
      expect(w.vm.canSubmitAdminAction).toBe(true);
    });

    it("calls submitAdminAction for move-to-rule", async () => {
      submitAdminAction.mockResolvedValue({
        data: { review: { ...sampleReview, rule_id: 99 } },
      });
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
      });
      vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

      w.vm.adminAction = "move-to-rule";
      w.vm.adminAuditComment = "belongs on rule 99";
      w.vm.adminTargetRuleId = 99;
      await w.vm.doSubmitAdminAction();
      await flushPromises(w);

      expect(submitAdminAction).toHaveBeenCalledWith(
        142, "move-to-rule", { audit_comment: "belongs on rule 99", rule_id: 99 },
      );
    });
  });

  // ==========================================================================
  // edit comment section retroactive. Triager (author+)
  // retags a comment to the correct XCCDF section without rejecting the
  // commenter. Audit-comment required. Backend gates author+ via
  // authorize_author_project + reject_if_frozen_for_writes.
  // ==========================================================================
  describe("section editing", () => {
    it("hides the Edit section affordance for viewer-tier users", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "viewer" },
        stubs: visibleModalStub,
      });
      expect(w.vm.canEditSection).toBe(false);
    });

    it("shows the Edit section affordance for author-tier users", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "author" },
        stubs: visibleModalStub,
      });
      expect(w.vm.canEditSection).toBe(true);
    });

    it("shows the Edit section affordance for admins", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
        stubs: visibleModalStub,
      });
      expect(w.vm.canEditSection).toBe(true);
    });

    it("offers a section picker that includes (general) plus the canonical XCCDF keys", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "author" },
        stubs: visibleModalStub,
      });
      const opts = w.vm.sectionOptions;
      expect(opts.find((o) => o.value === null)).toBeTruthy();
      expect(opts.find((o) => o.value === "check_content")).toBeTruthy();
      expect(opts.find((o) => o.value === "fixtext")).toBeTruthy();
    });

    it("canSubmitSectionChange requires a non-blank audit comment", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "author" },
      });
      w.vm.sectionEditMode = true;
      w.vm.newSection = "fixtext";
      w.vm.sectionAuditComment = "";
      expect(w.vm.canSubmitSectionChange).toBe(false);
      w.vm.sectionAuditComment = "retagging — was wrong";
      expect(w.vm.canSubmitSectionChange).toBe(true);
    });

    it("calls updateSection with section + audit_comment, emits 'triaged', and hides the modal", async () => {
      updateSection.mockResolvedValue({
        data: { review: { ...sampleReview, section: "fixtext" } },
      });
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "author" },
        stubs: visibleModalStub,
      });
      const hideSpy = vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

      w.vm.sectionEditMode = true;
      w.vm.newSection = "fixtext";
      w.vm.sectionAuditComment = "should have been Fix";
      await w.vm.submitSectionChange();
      await flushPromises(w);

      expect(updateSection).toHaveBeenCalledWith(142, "fixtext", "should have been Fix");
      expect(w.emitted("triaged")).toBeTruthy();
      expect(hideSpy).toHaveBeenCalledWith("comment-triage-modal");

      // form-state cleanup must run BEFORE
      // (or alongside) hide. A regression that calls hide without resetting
      // would leak prior values into the next time the modal opens.
      expect(w.vm.sectionEditMode).toBe(false);
      expect(w.vm.sectionAuditComment).toBe("");
      expect(w.vm.newSection).toBe(null);
    });

    it("accepts null to retag back to (general)", async () => {
      updateSection.mockResolvedValue({
        data: { review: { ...sampleReview, section: null } },
      });
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "author" },
      });

      w.vm.sectionEditMode = true;
      w.vm.newSection = null;
      w.vm.sectionAuditComment = "general after all";
      await w.vm.submitSectionChange();
      await flushPromises(w);

      expect(updateSection).toHaveBeenCalledWith(142, null, "general after all");
    });

    it("surfaces server errors via AlertMixin without crashing", async () => {
      updateSection.mockRejectedValueOnce({ response: { status: 422, data: {} } });
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "author" },
      });
      const alertSpy = vi.spyOn(w.vm, "alertOrNotifyResponse").mockImplementation(() => {});

      w.vm.sectionEditMode = true;
      w.vm.newSection = "fixtext";
      w.vm.sectionAuditComment = "x";
      await w.vm.submitSectionChange();
      await flushPromises(w);

      expect(alertSpy).toHaveBeenCalled();
      alertSpy.mockRestore();
    });

    it("cancelSectionEdit clears the sub-form state", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "author" },
      });
      w.vm.sectionEditMode = true;
      w.vm.newSection = "fixtext";
      w.vm.sectionAuditComment = "retagging";
      w.vm.cancelSectionEdit();

      expect(w.vm.sectionEditMode).toBe(false);
      expect(w.vm.newSection).toBe(null);
      expect(w.vm.sectionAuditComment).toBe("");
    });
  });

  // modal shows "Triaged by ... · time" and
  // "Adjudicated by ... · time" when those events have happened. When the
  // attribution came from a JSON archive restore where the original User
  // doesn't exist on this instance, we show the imported name/email plus an
  // "imported" badge so reviewers know the trail is real but unmapped.
  describe("attribution display", () => {
    const triagedReview = {
      ...sampleReview,
      triage_status: "concur",
      triage_set_at: "2026-04-28T10:00:00Z",
      triager_display_name: "Triager Tee",
      triager_imported: false,
      adjudicated_at: "2026-04-29T11:00:00Z",
      adjudicator_display_name: "Adjudicator Aye",
      adjudicator_imported: false,
    };

    it("does not render attribution lines for a pending (untriaged) review", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview },
        stubs: visibleModalStub,
      });
      const html = w.html();
      expect(html).not.toContain("Triaged by");
      expect(html).not.toContain("Adjudicated by");
    });

    it("renders 'Triaged by' with the display name when triage_set_at is present", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: triagedReview },
        stubs: visibleModalStub,
      });
      const block = w.find('[data-testid="attribution-triaged"]');
      expect(block.exists()).toBe(true);
      expect(block.text()).toContain("Triaged by");
      expect(block.text()).toContain("Triager Tee");
      expect(block.text()).not.toContain("imported");
    });

    it("renders 'Adjudicated by' with the display name when adjudicated_at is present", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: triagedReview },
        stubs: visibleModalStub,
      });
      const block = w.find('[data-testid="attribution-adjudicated"]');
      expect(block.exists()).toBe(true);
      expect(block.text()).toContain("Adjudicated by");
      expect(block.text()).toContain("Adjudicator Aye");
    });

    it("shows an 'imported' badge when triager_imported is true", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: {
          review: { ...triagedReview, triager_display_name: "Old Triager", triager_imported: true },
        },
        stubs: visibleModalStub,
      });
      const block = w.find('[data-testid="attribution-triaged"]');
      expect(block.text()).toContain("Old Triager");
      expect(block.text()).toContain("imported");
    });

    it("shows an 'imported' badge when adjudicator_imported is true", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: {
          review: {
            ...triagedReview,
            adjudicator_display_name: "old@former.example",
            adjudicator_imported: true,
          },
        },
        stubs: visibleModalStub,
      });
      const block = w.find('[data-testid="attribution-adjudicated"]');
      expect(block.text()).toContain("old@former.example");
      expect(block.text()).toContain("imported");
    });

    it("renders an em-dash placeholder when display_name is null but the event happened", () => {
      // Defensive case: triage_set_at set but no FK and no imported_* (shouldn't
      // happen with current code paths, but the modal should not crash).
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: {
          review: { ...triagedReview, triager_display_name: null, triager_imported: false },
        },
        stubs: visibleModalStub,
      });
      const block = w.find('[data-testid="attribution-triaged"]');
      expect(block.exists()).toBe(true);
      expect(block.text()).toContain("—");
    });
  });

  // commenter attribution
  // badge in the byline area (top of the modal). When the original
  // commenter's User row is gone (User#destroy nullified user_id) but
  // commenter_imported_email/name are populated, the byline shows the
  // imported name + an "imported" badge — matches the triager_/
  // adjudicator_ pattern below.
  describe("commenter attribution byline", () => {
    it("shows the resolved User name and no imported badge when commenter_imported is false", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: {
          review: {
            ...sampleReview,
            commenter_display_name: "John Doe",
            commenter_imported: false,
          },
        },
        stubs: visibleModalStub,
      });
      const block = w.find('[data-testid="attribution-commenter"]');
      expect(block.exists()).toBe(true);
      expect(block.text()).toContain("John Doe");
      expect(block.text()).not.toContain("imported");
    });

    it("shows the imported attribution name + 'imported' badge when commenter_imported is true", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: {
          review: {
            ...sampleReview,
            commenter_display_name: "Former User",
            commenter_imported: true,
            author_name: null, // simulating User#destroy nullification
          },
        },
        stubs: visibleModalStub,
      });
      const block = w.find('[data-testid="attribution-commenter"]');
      expect(block.exists()).toBe(true);
      expect(block.text()).toContain("Former User");
      expect(block.text()).toContain("imported");
    });

    it("renders an em-dash placeholder when commenter_display_name is null", () => {
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: {
          review: {
            ...sampleReview,
            commenter_display_name: null,
            commenter_imported: false,
            author_name: null,
          },
        },
        stubs: visibleModalStub,
      });
      const block = w.find('[data-testid="attribution-commenter"]');
      expect(block.exists()).toBe(true);
      expect(block.text()).toContain("—");
    });
  });
});
