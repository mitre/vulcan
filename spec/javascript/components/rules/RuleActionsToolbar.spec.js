import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleActionsToolbar from "@/components/rules/RuleActionsToolbar.vue";

/**
 * RuleActionsToolbar - Rule-level actions and panels
 *
 * REQUIREMENTS:
 *
 * 1. BUTTON ORDER (left to right, safe → destructive):
 *    Info/Reference: Related, Satisfies, History, Comment History (read-only panels)
 *    Collaboration: Comment, Change Review Status (team interaction)
 *    Edit: Save, Clone (modify/create data)
 *    Admin: Delete, Lock/Unlock (destructive/restricted)
 *
 * 2. PANEL BUTTONS (info/reference):
 *    - Related: Opens RelatedRulesModal (always available)
 *    - Satisfies: Opens satisfies panel (always available)
 *    - History: Opens rule history panel (always available)
 *    - Comment History: Opens rule reviews panel (always available)
 *
 * 3. ACTION BUTTONS:
 *    - Comment: Always available
 *    - Change Review Status: Disabled in read-only mode
 *    - Save: Disabled when locked/under review or read-only
 *    - Clone: Disabled in read-only mode
 *    - Delete: Admin only, disabled when locked/under review
 *    - Lock/Unlock: Admin only
 *
 * 4. PERMISSIONS:
 *    - Delete and Lock/Unlock only visible to admin
 *    - Other actions respect readOnly prop and rule state
 */
describe("RuleActionsToolbar", () => {
  let wrapper;

  const defaultRule = {
    id: 1,
    rule_id: "00001",
    locked: false,
    review_requestor_id: null,
  };

  const createWrapper = (props = {}) => {
    return mount(RuleActionsToolbar, {
      localVue,
      propsData: {
        rule: defaultRule,
        effectivePermissions: "admin",
        readOnly: false,
        ...props,
      },
      stubs: {
        CommentModal: {
          template:
            '<button class="comment-modal-stub" :disabled="buttonDisabled" @click="$emit(\'comment\', \'test\')">{{ buttonText }}</button>',
          props: ["buttonText", "buttonDisabled", "buttonIcon", "buttonVariant", "buttonSize"],
        },
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // ==========================================
  // BUTTON ORDER
  // ==========================================
  describe("button order", () => {
    it("renders buttons in correct order: Info → Collaboration → Edit → Admin", () => {
      wrapper = createWrapper();
      const buttons = wrapper.findAll("button, .comment-modal-stub");
      const buttonTexts = buttons.wrappers.map((b) => b.text().trim());

      // Expected order: Related, Satisfies, History, Comment History, Comment, Change Review Status, Save, Clone, Delete, Lock
      const expectedOrder = [
        "Related",
        "Satisfies",
        "History",
        "Comment History",
        "Comment",
        "Change Review Status",
        "Save",
        "Clone",
        "Delete",
        "Lock",
      ];

      expectedOrder.forEach((label, index) => {
        expect(buttonTexts[index]).toContain(label);
      });
    });
  });

  // ==========================================
  // PANEL BUTTONS (Info/Reference)
  // ==========================================
  describe("panel buttons", () => {
    it("shows Related button", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Related");
    });

    it("shows Satisfies button", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Satisfies");
    });

    it("shows History button", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("History");
    });

    it("shows Comment History button", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Comment History");
    });

    it("emits open-related-modal when Related clicked", async () => {
      wrapper = createWrapper();
      const btn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("Related"));
      await btn.trigger("click");
      expect(wrapper.emitted("open-related-modal")).toBeTruthy();
    });

    it('emits toggle-panel with "satisfies" when Satisfies clicked', async () => {
      wrapper = createWrapper();
      const btn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("Satisfies"));
      await btn.trigger("click");
      expect(wrapper.emitted("toggle-panel")).toBeTruthy();
      expect(wrapper.emitted("toggle-panel")[0]).toEqual(["satisfies"]);
    });

    it('emits toggle-panel with "rule-history" when History clicked', async () => {
      wrapper = createWrapper();
      const btn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("History"));
      await btn.trigger("click");
      expect(wrapper.emitted("toggle-panel")).toBeTruthy();
      expect(wrapper.emitted("toggle-panel")[0]).toEqual(["rule-history"]);
    });

    it('emits toggle-panel with "rule-reviews" when Comment History clicked', async () => {
      wrapper = createWrapper();
      const btn = wrapper
        .findAll("button")
        .wrappers.find((b) => b.text().includes("Comment History"));
      await btn.trigger("click");
      expect(wrapper.emitted("toggle-panel")).toBeTruthy();
      expect(wrapper.emitted("toggle-panel")[0]).toEqual(["rule-reviews"]);
    });

    it("panel buttons are NOT disabled even in read-only mode", () => {
      wrapper = createWrapper({ readOnly: true });
      const relatedBtn = wrapper
        .findAll("button")
        .wrappers.find((b) => b.text().includes("Related"));
      const satisfiesBtn = wrapper
        .findAll("button")
        .wrappers.find((b) => b.text().includes("Satisfies"));
      const historyBtn = wrapper
        .findAll("button")
        .wrappers.find((b) => b.text().includes("History"));
      const reviewsBtn = wrapper
        .findAll("button")
        .wrappers.find((b) => b.text().includes("Comment History"));

      expect(relatedBtn.attributes("disabled")).toBeUndefined();
      expect(satisfiesBtn.attributes("disabled")).toBeUndefined();
      expect(historyBtn.attributes("disabled")).toBeUndefined();
      expect(reviewsBtn.attributes("disabled")).toBeUndefined();
    });
  });

  // ==========================================
  // ACTION BUTTONS
  // ==========================================
  describe("action buttons", () => {
    describe("Comment button", () => {
      // The button text is just "Comment" — match exactly so we don't pick
      // up the "Comment History" panel button or "Change Review Status".
      const findCommentButton = (w) =>
        w.findAll("button").wrappers.find((b) => b.text().trim() === "Comment");

      it("is always visible", () => {
        wrapper = createWrapper();
        expect(findCommentButton(wrapper)).toBeDefined();
      });

      it("emits open-composer with null section (general comment) on click", async () => {
        wrapper = createWrapper();
        const btn = findCommentButton(wrapper);
        expect(btn).toBeDefined();
        await btn.trigger("click");
        expect(wrapper.emitted("open-composer")).toBeTruthy();
        expect(wrapper.emitted("open-composer")[0]).toEqual([null]);
      });

      // Viewers can comment — the Comment button is the one collaboration
      // action that doesn't require write permission.
      it("is enabled even when readOnly=true (viewer scenario)", () => {
        wrapper = createWrapper({ readOnly: true, effectivePermissions: "viewer" });
        const btn = findCommentButton(wrapper);
        expect(btn).toBeDefined();
        expect(btn.attributes("disabled")).toBeUndefined();
      });

      // Status precondition (NYD) used to gate this button. Removed:
      // viewers should be able to comment on a requirement before its
      // status is set.
      it("is enabled when rule.status === 'Not Yet Determined'", () => {
        wrapper = createWrapper({
          rule: { ...defaultRule, status: "Not Yet Determined" },
        });
        const btn = findCommentButton(wrapper);
        expect(btn).toBeDefined();
        expect(btn.attributes("disabled")).toBeUndefined();
      });

      it("is disabled when rule.locked === true", () => {
        wrapper = createWrapper({
          rule: { ...defaultRule, locked: true },
        });
        const btn = findCommentButton(wrapper);
        expect(btn).toBeDefined();
        expect(btn.attributes("disabled")).toBeDefined();
        expect(btn.attributes("title")).toMatch(/lock/i);
      });

      it("is disabled when the component's comments are closed (injected)", () => {
        wrapper = mount(RuleActionsToolbar, {
          localVue,
          propsData: {
            rule: defaultRule,
            effectivePermissions: "admin",
            readOnly: false,
          },
          provide: {
            isCommentsClosed: () => true,
          },
          stubs: {
            CommentModal: {
              template:
                '<button class="comment-modal-stub" :disabled="buttonDisabled">{{ buttonText }}</button>',
              props: ["buttonText", "buttonDisabled", "buttonIcon", "buttonVariant", "buttonSize"],
            },
          },
        });
        const btn = findCommentButton(wrapper);
        expect(btn).toBeDefined();
        expect(btn.attributes("disabled")).toBeDefined();
        // Default "no reason" tooltip — see commentsClosedTooltip().
        expect(btn.attributes("title")).toMatch(/not enabled/i);
      });

      it("Save button IS disabled when readOnly=true (viewer scenario)", () => {
        wrapper = createWrapper({ readOnly: true, effectivePermissions: "viewer" });
        const saveStub = wrapper
          .findAll(".comment-modal-stub")
          .wrappers.find((s) => s.text().includes("Save"));
        expect(saveStub).toBeDefined();
        expect(saveStub.attributes("disabled")).toBe("disabled");
      });
    });

    describe("Change Review Status button", () => {
      // C1: Button text should be "Change Review Status" not just "Review"
      // REQUIREMENT: Label must clearly indicate the action changes review status (state-changing operation)
      it("displays button text 'Change Review Status'", () => {
        wrapper = createWrapper();
        expect(wrapper.text()).toContain("Change Review Status");
      });

      it("is disabled in read-only mode", () => {
        wrapper = createWrapper({ readOnly: true });
        const btn = wrapper
          .findAll("button")
          .wrappers.find((b) => b.text().includes("Change Review Status"));
        expect(btn.attributes("disabled")).toBe("disabled");
      });

      it("emits open-review-modal when clicked", async () => {
        wrapper = createWrapper();
        const btn = wrapper
          .findAll("button")
          .wrappers.find((b) => b.text().includes("Change Review Status"));
        await btn.trigger("click");
        expect(wrapper.emitted("open-review-modal")).toBeTruthy();
      });
    });

    describe("Save button", () => {
      it("is visible", () => {
        wrapper = createWrapper();
        expect(wrapper.text()).toContain("Save");
      });

      it("is disabled when rule is locked", () => {
        wrapper = createWrapper({ rule: { ...defaultRule, locked: true } });
        const saveStub = wrapper
          .findAll(".comment-modal-stub")
          .wrappers.find((b) => b.text().includes("Save"));
        expect(saveStub.attributes("disabled")).toBe("disabled");
      });

      it("is disabled when rule is under review", () => {
        wrapper = createWrapper({ rule: { ...defaultRule, review_requestor_id: 123 } });
        const saveStub = wrapper
          .findAll(".comment-modal-stub")
          .wrappers.find((b) => b.text().includes("Save"));
        expect(saveStub.attributes("disabled")).toBe("disabled");
      });
    });

    describe("Clone button", () => {
      it("is visible", () => {
        wrapper = createWrapper();
        expect(wrapper.text()).toContain("Clone");
      });

      it("is disabled in read-only mode", () => {
        wrapper = createWrapper({ readOnly: true });
        const btn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("Clone"));
        expect(btn.attributes("disabled")).toBe("disabled");
      });

      it("emits clone event when clicked", async () => {
        wrapper = createWrapper();
        const btn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("Clone"));
        await btn.trigger("click");
        expect(wrapper.emitted("clone")).toBeTruthy();
      });
    });
  });

  // ==========================================
  // ADMIN BUTTONS
  // ==========================================
  describe("admin buttons", () => {
    describe("Delete button", () => {
      it("is visible for admin", () => {
        wrapper = createWrapper({ effectivePermissions: "admin" });
        expect(wrapper.text()).toContain("Delete");
      });

      it("is NOT visible for author", () => {
        wrapper = createWrapper({ effectivePermissions: "author" });
        expect(wrapper.text()).not.toContain("Delete");
      });

      it("is NOT visible for viewer", () => {
        wrapper = createWrapper({ effectivePermissions: "viewer" });
        expect(wrapper.text()).not.toContain("Delete");
      });

      it("is disabled when rule is locked", () => {
        wrapper = createWrapper({ rule: { ...defaultRule, locked: true } });
        const btn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("Delete"));
        expect(btn.attributes("disabled")).toBe("disabled");
      });

      it("emits delete event when clicked", async () => {
        wrapper = createWrapper();
        const btn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("Delete"));
        await btn.trigger("click");
        expect(wrapper.emitted("delete")).toBeTruthy();
      });
    });

    describe("Lock/Unlock button", () => {
      it("shows Lock button when rule is unlocked", () => {
        wrapper = createWrapper({ rule: { ...defaultRule, locked: false } });
        expect(wrapper.text()).toContain("Lock");
        expect(wrapper.text()).not.toContain("Unlock");
      });

      it("shows Unlock button when rule is locked", () => {
        wrapper = createWrapper({ rule: { ...defaultRule, locked: true } });
        expect(wrapper.text()).toContain("Unlock");
      });

      it("Lock is NOT visible for non-admin", () => {
        wrapper = createWrapper({ effectivePermissions: "author" });
        expect(wrapper.text()).not.toContain("Lock");
      });

      it("Lock is disabled when rule is under review", () => {
        wrapper = createWrapper({ rule: { ...defaultRule, review_requestor_id: 123 } });
        const lockStub = wrapper
          .findAll(".comment-modal-stub")
          .wrappers.find((b) => b.text().includes("Lock"));
        expect(lockStub.attributes("disabled")).toBe("disabled");
      });
    });
  });
});
