import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import axios from "axios";
import CommentTriageModal from "@/components/components/CommentTriageModal.vue";

vi.mock("axios");

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

  it("requires response_comment when triage_status=non_concur (client-side gate)", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    w.vm.triageStatus = "non_concur";
    w.vm.responseComment = "";
    expect(w.vm.canSave).toBe(false);
    w.vm.responseComment = "we already addressed differently";
    expect(w.vm.canSave).toBe(true);
  });

  it("requires duplicate_of_review_id when triage_status=duplicate", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    w.vm.triageStatus = "duplicate";
    w.vm.duplicateOfId = null;
    expect(w.vm.canSave).toBe(false);
    w.vm.duplicateOfId = 99;
    expect(w.vm.canSave).toBe(true);
  });

  it("posts to /reviews/:id/triage on Save decision", async () => {
    axios.patch.mockResolvedValue({
      data: { review: { ...sampleReview, triage_status: "concur" } },
    });
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    w.vm.triageStatus = "concur";
    w.vm.responseComment = "thanks";
    await w.vm.saveTriage(false);
    await flushPromises(w);

    expect(axios.patch).toHaveBeenCalledWith(
      "/reviews/142/triage",
      expect.objectContaining({ triage_status: "concur", response_comment: "thanks" }),
    );
    expect(w.emitted("triaged")).toBeTruthy();
  });

  it("'Save & close' fires triage AND adjudicate atomically", async () => {
    axios.patch
      .mockResolvedValueOnce({
        data: { review: { ...sampleReview, triage_status: "concur" } },
      })
      .mockResolvedValueOnce({
        data: {
          review: { ...sampleReview, triage_status: "concur", adjudicated_at: "2026-04-29T12:00Z" },
        },
      });
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    w.vm.triageStatus = "concur";
    w.vm.responseComment = "done";
    await w.vm.saveTriage(true);
    await flushPromises(w);

    expect(axios.patch).toHaveBeenCalledTimes(2);
    expect(axios.patch.mock.calls[1][0]).toBe("/reviews/142/adjudicate");
    expect(w.emitted("adjudicated")).toBeTruthy();
  });

  it("collapses the footer to one button for terminal-by-rule statuses (no separate 'Save decision' option)", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    ["informational", "duplicate", "needs_clarification", "withdrawn"].forEach((status) => {
      w.vm.triageStatus = status;
      expect(w.vm.autoAdjudicating).toBe(true);
      expect(w.vm.hasSaveDecisionOnlyOption).toBe(false);
    });
    w.vm.triageStatus = "concur";
    expect(w.vm.autoAdjudicating).toBe(false);
    expect(w.vm.hasSaveDecisionOnlyOption).toBe(true);
  });

  it("relabels the primary button to 'Save & wait for commenter' when status is needs_clarification", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    w.vm.triageStatus = "needs_clarification";
    expect(w.vm.saveAndCloseLabel).toBe("Save & wait for commenter");
    w.vm.triageStatus = "concur";
    expect(w.vm.saveAndCloseLabel).toBe("Save & close");
  });

  it("skips the redundant adjudicate call for auto-adjudicating statuses", async () => {
    axios.patch.mockResolvedValueOnce({
      data: { review: { ...sampleReview, triage_status: "informational" } },
    });
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    w.vm.triageStatus = "informational";
    await w.vm.saveTriage(true);
    await flushPromises(w);

    expect(axios.patch).toHaveBeenCalledTimes(1);
    expect(axios.patch.mock.calls[0][0]).toBe("/reviews/142/triage");
    expect(w.emitted("adjudicated")).toBeFalsy();
  });

  it("surfaces server errors via AlertMixin without crashing", async () => {
    axios.patch.mockRejectedValueOnce({ response: { status: 422, data: {} } });
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview },
    });
    const alertSpy = vi.spyOn(w.vm, "alertOrNotifyResponse").mockImplementation(() => {});

    w.vm.triageStatus = "concur";
    await w.vm.saveTriage(false);
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
  // PR-717 Task 25 — admin force-withdraw + restore actions inside the modal.
  // Visible only when the current user has effective admin permissions.
  // Audit comment is required server-side; UI gates the Confirm button.
  // ==========================================================================
  describe("admin actions disclosure (PR-717 Task 25)", () => {
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

    it("posts to /reviews/:id/admin_withdraw with the audit comment", async () => {
      axios.patch.mockResolvedValue({
        data: { review: { ...sampleReview, triage_status: "withdrawn" } },
      });
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
      });
      vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

      w.vm.adminAction = "force-withdraw";
      w.vm.adminAuditComment = "spam content removed";
      await w.vm.submitAdminAction();
      await flushPromises(w);

      expect(axios.patch).toHaveBeenCalledWith(
        "/reviews/142/admin_withdraw",
        expect.objectContaining({ audit_comment: "spam content removed" }),
      );
    });

    it("posts to /reviews/:id/admin_restore with the audit comment", async () => {
      axios.patch.mockResolvedValue({
        data: { review: { ...adjudicatedReview, triage_status: "pending", adjudicated_at: null } },
      });
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: adjudicatedReview, effectivePermissions: "admin" },
      });
      vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

      w.vm.adminAction = "restore";
      w.vm.adminAuditComment = "withdrew the wrong one";
      await w.vm.submitAdminAction();
      await flushPromises(w);

      expect(axios.patch).toHaveBeenCalledWith(
        "/reviews/142/admin_restore",
        expect.objectContaining({ audit_comment: "withdrew the wrong one" }),
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
  // PR-717 Task 25b — admin hard-delete (irreversible). Typed-confirmation
  // safeguard: admin must type the review ID into a confirmation field
  // before the Confirm button enables. Audit comment is also required.
  // ==========================================================================
  describe("admin hard-delete (PR-717 Task 25b)", () => {
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

    it("posts DELETE to /reviews/:id/admin_destroy with the audit comment", async () => {
      axios.delete.mockResolvedValue({ data: { ok: true } });
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
      });
      vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

      w.vm.adminAction = "hard-delete";
      w.vm.adminAuditComment = "PII removed per legal";
      w.vm.adminConfirmationId = String(sampleReview.id);
      await w.vm.submitAdminAction();
      await flushPromises(w);

      expect(axios.delete).toHaveBeenCalledWith(
        "/reviews/142/admin_destroy",
        expect.objectContaining({
          data: expect.objectContaining({ audit_comment: "PII removed per legal" }),
        }),
      );
    });

    it("emits a 'destroyed' event after a successful hard-delete (parent table can remove the row)", async () => {
      axios.delete.mockResolvedValue({ data: { ok: true } });
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "admin" },
      });
      vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

      w.vm.adminAction = "hard-delete";
      w.vm.adminAuditComment = "cleanup";
      w.vm.adminConfirmationId = String(sampleReview.id);
      await w.vm.submitAdminAction();
      await flushPromises(w);

      expect(w.emitted("destroyed")).toBeTruthy();
      expect(w.emitted("destroyed")[0][0]).toBe(sampleReview.id);
    });
  });

  // ==========================================================================
  // PR-717 Task 26 — admin move-to-rule. Reassigns a misplaced comment
  // (and atomically all its replies via the controller's parent-first walk)
  // to a different rule in the same component. Audit comment required;
  // target rule chosen via the embedded RulePicker.
  // ==========================================================================
  describe("admin move-to-rule (PR-717 Task 26)", () => {
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

    it("posts to /reviews/:id/move_to_rule with rule_id and audit_comment", async () => {
      axios.patch.mockResolvedValue({
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
      await w.vm.submitAdminAction();
      await flushPromises(w);

      expect(axios.patch).toHaveBeenCalledWith(
        "/reviews/142/move_to_rule",
        expect.objectContaining({ audit_comment: "belongs on rule 99", rule_id: 99 }),
      );
    });
  });

  // ==========================================================================
  // PR-717 Task 30 — edit comment section retroactive. Triager (author+)
  // retags a comment to the correct XCCDF section without rejecting the
  // commenter. Audit-comment required. Backend gates author+ via
  // authorize_author_project + reject_if_frozen_for_writes.
  // ==========================================================================
  describe("section editing (PR-717 Task 30)", () => {
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

    it("posts to /reviews/:id/section with section + audit_comment, emits 'triaged', and hides the modal", async () => {
      axios.patch.mockResolvedValue({
        data: { review: { ...sampleReview, section: "fixtext" } },
      });
      const w = mount(CommentTriageModal, {
        localVue,
        propsData: { review: sampleReview, effectivePermissions: "author" },
      });
      const hideSpy = vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

      w.vm.sectionEditMode = true;
      w.vm.newSection = "fixtext";
      w.vm.sectionAuditComment = "should have been Fix";
      await w.vm.submitSectionChange();
      await flushPromises(w);

      expect(axios.patch).toHaveBeenCalledWith(
        "/reviews/142/section",
        expect.objectContaining({ section: "fixtext", audit_comment: "should have been Fix" }),
      );
      expect(w.emitted("triaged")).toBeTruthy();
      expect(hideSpy).toHaveBeenCalledWith("comment-triage-modal");

      // PR-717 review remediation .13 — form-state cleanup must run BEFORE
      // (or alongside) hide. A regression that calls hide without resetting
      // would leak prior values into the next time the modal opens.
      expect(w.vm.sectionEditMode).toBe(false);
      expect(w.vm.sectionAuditComment).toBe("");
      expect(w.vm.newSection).toBe(null);
    });

    it("accepts null to retag back to (general)", async () => {
      axios.patch.mockResolvedValue({
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

      expect(axios.patch).toHaveBeenCalledWith(
        "/reviews/142/section",
        expect.objectContaining({ section: null, audit_comment: "general after all" }),
      );
    });

    it("surfaces server errors via AlertMixin without crashing", async () => {
      axios.patch.mockRejectedValueOnce({ response: { status: 422, data: {} } });
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

  // PR-717 review remediation .8 — modal shows "Triaged by ... · time" and
  // "Adjudicated by ... · time" when those events have happened. When the
  // attribution came from a JSON archive restore where the original User
  // doesn't exist on this instance, we show the imported name/email plus an
  // "imported" badge so reviewers know the trail is real but unmapped.
  describe("attribution display (PR-717 .8)", () => {
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

  // PR-717 review remediation .j4a step C3 — commenter attribution
  // badge in the byline area (top of the modal). When the original
  // commenter's User row is gone (User#destroy nullified user_id) but
  // commenter_imported_email/name are populated, the byline shows the
  // imported name + an "imported" badge — matches the triager_/
  // adjudicator_ pattern below.
  describe("commenter attribution byline (PR-717 .j4a)", () => {
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
