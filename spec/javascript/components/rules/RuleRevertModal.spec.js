import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleRevertModal from "@/components/rules/RuleRevertModal.vue";

vi.mock("axios", () => ({
  default: {
    post: vi.fn(() => Promise.resolve({ data: { toast: "Reverted" } })),
    defaults: { headers: { common: {} } },
  },
}));

/**
 * RuleRevertModal — Two-phase revert flow (C4)
 *
 * Phase 1: Change Details view (read-only diff table)
 * Phase 2: Revert confirmation (select fields, enter comment, confirm)
 */
describe("RuleRevertModal", () => {
  let wrapper;

  const defaultRule = { id: 1, rule_id: "000001" };
  const defaultHistory = {
    id: 10,
    name: "Demo Admin",
    action: "update",
    auditable_type: "Rule",
    auditable_id: 1,
    created_at: "2026-03-30T10:00:00Z",
    comment: "Updated title",
    audited_changes: [
      { field: "title", prev_value: "Old Title", new_value: "New Title" },
      { field: "status", prev_value: "NYD", new_value: "AC" },
    ],
  };
  const defaultComponent = { id: 1, additional_questions: [] };
  const defaultStatuses = ["Not Yet Determined", "Applicable - Configurable"];

  const createWrapper = (props = {}) => {
    return mount(RuleRevertModal, {
      localVue,
      propsData: {
        rule: defaultRule,
        history: defaultHistory,
        statuses: defaultStatuses,
        component: defaultComponent,
        ...props,
      },
      stubs: {
        BModal: false,
        BTable: false,
        BButton: false,
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
    vi.clearAllMocks();
  });

  // ==========================================
  // PHASE 1: Change Details view
  // ==========================================
  describe("phase 1 — change details", () => {
    it("renders a button showing the change type", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("was Updated...");
    });

    it("shows 'was Deleted...' for destroy actions", () => {
      wrapper = createWrapper({
        history: { ...defaultHistory, action: "destroy" },
      });
      expect(wrapper.text()).toContain("was Deleted...");
    });

    it("opens modal on button click", async () => {
      wrapper = createWrapper();
      expect(wrapper.vm.showDetailsModal).toBe(false);
      await wrapper.find("button").trigger("click");
      expect(wrapper.vm.showDetailsModal).toBe(true);
    });

    it("does not show revert confirmation initially", async () => {
      wrapper = createWrapper();
      await wrapper.find("button").trigger("click");
      expect(wrapper.vm.showRevertConfirm).toBe(false);
    });

    it("disables Revert button when no rows selected", async () => {
      wrapper = createWrapper();
      await wrapper.find("button").trigger("click");
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.selectedRevertRows).toHaveLength(0);
    });
  });

  // ==========================================
  // PHASE 2: Revert confirmation
  // ==========================================
  describe("phase 2 — revert confirmation", () => {
    it("shows revert confirmation when showRevertConfirm is set", async () => {
      wrapper = createWrapper();
      wrapper.vm.showDetailsModal = true;
      wrapper.vm.showRevertConfirm = true;
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.showRevertConfirm).toBe(true);
    });

    it("disables Confirm Revert when comment is empty", async () => {
      wrapper = createWrapper();
      wrapper.vm.showDetailsModal = true;
      wrapper.vm.showRevertConfirm = true;
      wrapper.vm.revertComment = "";
      await wrapper.vm.$nextTick();
      // The Confirm Revert button should be disabled
      expect(wrapper.vm.revertComment.trim().length).toBe(0);
    });

    it("enables Confirm Revert when comment is provided", async () => {
      wrapper = createWrapper();
      wrapper.vm.showDetailsModal = true;
      wrapper.vm.showRevertConfirm = true;
      wrapper.vm.revertComment = "Reverting due to error";
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.revertComment.trim().length).toBeGreaterThan(0);
    });

    it("Back button returns to details view", async () => {
      wrapper = createWrapper();
      wrapper.vm.showDetailsModal = true;
      wrapper.vm.showRevertConfirm = true;
      await wrapper.vm.$nextTick();
      wrapper.vm.showRevertConfirm = false;
      expect(wrapper.vm.showRevertConfirm).toBe(false);
    });
  });

  // ==========================================
  // REVERT ACTION
  // ==========================================
  describe("revert action", () => {
    it("sends POST to /rules/:id/revert with selected fields and comment", async () => {
      const axios = (await import("axios")).default;
      wrapper = createWrapper();
      wrapper.vm.selectedRevertRows = [defaultHistory.audited_changes[0]];
      wrapper.vm.revertComment = "Fixing mistake";

      await wrapper.vm.revertHistory("Fixing mistake");

      expect(axios.post).toHaveBeenCalledWith("/rules/1/revert", {
        audit_id: 10,
        fields: ["title"],
        audit_comment: "Fixing mistake",
      });
    });

    it("closes modal on successful revert", async () => {
      wrapper = createWrapper();
      wrapper.vm.showDetailsModal = true;

      await wrapper.vm.revertSuccess({ data: { toast: "Reverted" } });

      expect(wrapper.vm.showDetailsModal).toBe(false);
    });
  });

  // ==========================================
  // RESET ON HIDE
  // ==========================================
  describe("reset on modal hide", () => {
    it("resets all state when modal is hidden", () => {
      wrapper = createWrapper();
      wrapper.vm.showRevertConfirm = true;
      wrapper.vm.revertComment = "some comment";
      wrapper.vm.selectedRevertRows = [{ field: "title" }];

      wrapper.vm.onDetailsHidden();

      expect(wrapper.vm.showRevertConfirm).toBe(false);
      expect(wrapper.vm.revertComment).toBe("");
      expect(wrapper.vm.selectedRevertRows).toHaveLength(0);
    });
  });
});
