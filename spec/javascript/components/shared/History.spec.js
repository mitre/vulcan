import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import History from "@/components/shared/History.vue";

/**
 * History Component Requirements:
 *
 * 1. DISPLAY:
 *    - Shows grouped audit histories with user name and datetime
 *    - Shows comments when present on a history group
 *    - Groups histories by name, created_at (rounded to minute), and comment
 *
 * 2. ALL GROUPS VISIBLE:
 *    - All history groups are rendered (no pagination)
 *    - Content scrolls naturally in parent container
 *
 * 3. ACTION DISPLAY:
 *    - Create action: green text with "was Created" (or membership-specific text)
 *    - Update action: info text with "field was updated from X to Y"
 *    - Destroy action: danger text with "Deleted" (or membership-specific text)
 *
 * 4. ABBREVIATED MODE:
 *    - When abbreviateType is set, shows simplified text
 *    - Create: "UserType was created"
 *    - Update with deleted_at: danger "was deleted"
 *    - Update without deleted_at: info "was updated"
 *
 * 5. REVERTABLE MODE:
 *    - When revertable=true AND action is update/destroy, shows RuleRevertModal
 *    - When revertable=false, shows inline text instead
 *
 * 6. USER IDENTIFIER:
 *    - Returns humanized audited_name if available
 *    - Falls back to "Type ID" format (e.g., "Rule 42")
 */
describe("History", () => {
  let wrapper;

  // Factory for a single history audit record
  const makeHistory = (overrides = {}) => ({
    id: 1,
    name: "Admin User",
    created_at: "2024-06-15T10:30:00.000Z",
    comment: null,
    action: "update",
    audited_name: "title",
    auditable_type: "BaseRule",
    auditable_id: 42,
    audited_changes: [{ field: "title", prev_value: "Old Title", new_value: "New Title" }],
    ...overrides,
  });

  const createWrapper = (props = {}) => {
    return mount(History, {
      localVue,
      propsData: {
        histories: [],
        revertable: false,
        ...props,
      },
      stubs: {
        RuleRevertModal: {
          template: '<div class="rule-revert-stub" />',
          props: ["rule", "component", "history", "statuses"],
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
  // GROUP DISPLAY
  // ==========================================
  describe("group display", () => {
    it("renders history groups with name", () => {
      wrapper = createWrapper({
        histories: [makeHistory({ name: "Jane Doe" })],
      });
      expect(wrapper.text()).toContain("Jane Doe");
    });

    it("renders history groups with formatted date", () => {
      wrapper = createWrapper({
        histories: [makeHistory({ created_at: "2024-06-15T10:30:00.000Z" })],
      });
      // moment.format('lll') produces locale-dependent output like "Jun 15, 2024 10:30 AM"
      // Just verify a date-like string is rendered
      expect(wrapper.text()).toMatch(/Jun\s+15/);
    });

    it("shows comment when present on history group", () => {
      wrapper = createWrapper({
        histories: [makeHistory({ comment: "Updated per review feedback" })],
      });
      expect(wrapper.text()).toContain("Updated per review feedback");
    });

    it("does not show comment paragraph when comment is null", () => {
      wrapper = createWrapper({
        histories: [makeHistory({ comment: null })],
      });
      // The comment text should not appear
      expect(wrapper.text()).not.toContain("null");
    });

    it("groups histories by name, time, and comment", () => {
      const time = "2024-06-15T10:30:15.000Z";
      const histories = [
        makeHistory({ id: 1, name: "Admin", created_at: time, comment: null }),
        makeHistory({ id: 2, name: "Admin", created_at: time, comment: null }),
        makeHistory({
          id: 3,
          name: "Other User",
          created_at: time,
          comment: null,
        }),
      ];
      wrapper = createWrapper({ histories });

      // Should produce 2 groups (Admin group + Other User group)
      expect(wrapper.vm.groupedHistories.length).toBe(2);
    });
  });

  // ==========================================
  // ALL GROUPS VISIBLE
  // ==========================================
  describe("all groups visible", () => {
    it("renders all history groups without pagination", () => {
      const manyHistories = [
        makeHistory({ id: 1, name: "User A", created_at: "2024-06-15T10:00:00.000Z" }),
        makeHistory({ id: 2, name: "User B", created_at: "2024-06-15T11:00:00.000Z" }),
        makeHistory({ id: 3, name: "User C", created_at: "2024-06-15T12:00:00.000Z" }),
        makeHistory({ id: 4, name: "User D", created_at: "2024-06-15T13:00:00.000Z" }),
      ];
      wrapper = createWrapper({ histories: manyHistories });
      expect(wrapper.vm.groupedHistories.length).toBe(4);
      expect(wrapper.text()).toContain("User A");
      expect(wrapper.text()).toContain("User D");
      expect(wrapper.text()).not.toContain("show more");
      expect(wrapper.text()).not.toContain("show less");
    });
  });

  // ==========================================
  // CREATE ACTION
  // ==========================================
  describe("create action", () => {
    it("shows green text for create action", () => {
      wrapper = createWrapper({
        histories: [
          makeHistory({
            action: "create",
            audited_name: "title",
            auditable_type: "BaseRule",
          }),
        ],
      });
      const successText = wrapper.find(".text-success");
      expect(successText.exists()).toBe(true);
    });

    it('shows "Created" for non-Membership create', () => {
      wrapper = createWrapper({
        histories: [
          makeHistory({
            action: "create",
            auditable_type: "BaseRule",
          }),
        ],
      });
      expect(wrapper.text()).toContain("Created");
    });

    it("shows membership-specific text for Membership create", () => {
      wrapper = createWrapper({
        histories: [
          makeHistory({
            action: "create",
            auditable_type: "Membership",
            audited_changes: [{ field: "role", new_value: "author" }],
          }),
        ],
      });
      expect(wrapper.text()).toContain("added as a member with author permissions");
    });
  });

  // ==========================================
  // UPDATE ACTION (non-revertable)
  // ==========================================
  describe("update action (non-revertable)", () => {
    it("shows info text for update action", () => {
      wrapper = createWrapper({
        revertable: false,
        histories: [
          makeHistory({
            action: "update",
            audited_changes: [{ field: "title", prev_value: "Old", new_value: "New" }],
          }),
        ],
      });
      const infoText = wrapper.find(".text-info");
      expect(infoText.exists()).toBe(true);
    });

    it("shows field update text with from/to values", () => {
      wrapper = createWrapper({
        revertable: false,
        histories: [
          makeHistory({
            action: "update",
            audited_changes: [{ field: "title", prev_value: "Old Value", new_value: "New Value" }],
          }),
        ],
      });
      expect(wrapper.text()).toContain("title was updated from Old Value to New Value");
    });

    it("shows admin promotion text for admin field update", () => {
      wrapper = createWrapper({
        revertable: false,
        histories: [
          makeHistory({
            action: "update",
            audited_changes: [{ field: "admin", prev_value: false, new_value: true }],
          }),
        ],
      });
      expect(wrapper.text()).toContain("was promoted to admin");
    });

    it('shows "account was locked" for locked_at field set to a timestamp', () => {
      wrapper = createWrapper({
        revertable: false,
        histories: [
          makeHistory({
            action: "update",
            audited_changes: [
              { field: "locked_at", prev_value: null, new_value: "2024-06-15T10:30:00.000Z" },
            ],
          }),
        ],
      });
      expect(wrapper.text()).toContain("account was locked");
    });

    it('shows "account was unlocked" for locked_at field set to null', () => {
      wrapper = createWrapper({
        revertable: false,
        histories: [
          makeHistory({
            action: "update",
            audited_changes: [
              { field: "locked_at", prev_value: "2024-06-15T10:30:00.000Z", new_value: null },
            ],
          }),
        ],
      });
      expect(wrapper.text()).toContain("account was unlocked");
    });

    it("shows admin demotion text for admin field update to false", () => {
      wrapper = createWrapper({
        revertable: false,
        histories: [
          makeHistory({
            action: "update",
            audited_changes: [{ field: "admin", prev_value: true, new_value: false }],
          }),
        ],
      });
      expect(wrapper.text()).toContain("was demoted from admin");
    });
  });

  // ==========================================
  // DESTROY ACTION (non-revertable)
  // ==========================================
  describe("destroy action (non-revertable)", () => {
    it("shows danger text for destroy action", () => {
      wrapper = createWrapper({
        revertable: false,
        histories: [
          makeHistory({
            action: "destroy",
            auditable_type: "BaseRule",
          }),
        ],
      });
      const dangerText = wrapper.find(".text-danger");
      expect(dangerText.exists()).toBe(true);
    });

    it('shows "Deleted" for non-Membership destroy', () => {
      wrapper = createWrapper({
        revertable: false,
        histories: [
          makeHistory({
            action: "destroy",
            auditable_type: "BaseRule",
          }),
        ],
      });
      expect(wrapper.text()).toContain("Deleted");
    });

    it('shows "removed as a member" for Membership destroy', () => {
      wrapper = createWrapper({
        revertable: false,
        histories: [
          makeHistory({
            action: "destroy",
            auditable_type: "Membership",
          }),
        ],
      });
      expect(wrapper.text()).toContain("removed as a member");
    });
  });

  // ==========================================
  // ABBREVIATED MODE
  // ==========================================
  describe("abbreviated mode", () => {
    it('shows "was created" for create in abbreviated mode', () => {
      wrapper = createWrapper({
        abbreviateType: "Review",
        histories: [
          makeHistory({
            action: "create",
            audited_name: "Review",
          }),
        ],
      });
      expect(wrapper.find(".text-success").text()).toContain("was created");
    });

    it("shows danger text for update with deleted_at in abbreviated mode", () => {
      wrapper = createWrapper({
        abbreviateType: "Review",
        histories: [
          makeHistory({
            action: "update",
            audited_name: "Review",
            audited_changes: [{ field: "deleted_at", prev_value: null, new_value: "2024-01-01" }],
          }),
        ],
      });
      const dangerText = wrapper.find(".text-danger");
      expect(dangerText.exists()).toBe(true);
      expect(dangerText.text()).toContain("was deleted");
    });

    it("shows info text for update without deleted_at in abbreviated mode", () => {
      wrapper = createWrapper({
        abbreviateType: "Review",
        histories: [
          makeHistory({
            action: "update",
            audited_name: "Review",
            audited_changes: [{ field: "status", prev_value: "open", new_value: "closed" }],
          }),
        ],
      });
      const infoText = wrapper.find(".text-info");
      expect(infoText.exists()).toBe(true);
      expect(infoText.text()).toContain("was updated");
    });
  });

  // ==========================================
  // REVERTABLE MODE
  // ==========================================
  describe("revertable mode", () => {
    it("renders RuleRevertModal for update actions when revertable is true", () => {
      wrapper = createWrapper({
        revertable: true,
        rule: { id: 1 },
        component: { id: 1 },
        statuses: ["Applicable - Configurable"],
        histories: [makeHistory({ action: "update" })],
      });
      expect(wrapper.find(".rule-revert-stub").exists()).toBe(true);
    });

    it("renders RuleRevertModal for destroy actions when revertable is true", () => {
      wrapper = createWrapper({
        revertable: true,
        rule: { id: 1 },
        component: { id: 1 },
        statuses: ["Applicable - Configurable"],
        histories: [makeHistory({ action: "destroy" })],
      });
      expect(wrapper.find(".rule-revert-stub").exists()).toBe(true);
    });

    it("does not render RuleRevertModal when revertable is false", () => {
      wrapper = createWrapper({
        revertable: false,
        histories: [makeHistory({ action: "update" })],
      });
      expect(wrapper.find(".rule-revert-stub").exists()).toBe(false);
    });
  });

  // ==========================================
  // USER IDENTIFIER
  // ==========================================
  describe("userIdentifier", () => {
    it("returns humanized audited_name when available", () => {
      wrapper = createWrapper({ histories: [] });
      const result = wrapper.vm.userIdentifier({
        audited_name: "title",
        auditable_type: "BaseRule",
        auditable_id: 42,
      });
      // "title" maps to "Title" in humanizedTypes
      expect(result).toBe("Title");
    });

    it('returns "Type ID" fallback when audited_name is not in humanizedTypes', () => {
      wrapper = createWrapper({ histories: [] });
      const result = wrapper.vm.userIdentifier({
        audited_name: null,
        auditable_type: "BaseRule",
        auditable_id: 42,
      });
      // humanizedType("BaseRule") = "Rule", then "Rule 42"
      expect(result).toBe("Rule 42");
    });

    it("prettifies object values in update text", () => {
      wrapper = createWrapper({ histories: [] });
      const result = wrapper.vm.prettifyObjects({ key: "value" });
      expect(result).toBe(JSON.stringify({ key: "value" }, null, 4));
    });

    it("returns primitive values as-is from prettifyObjects", () => {
      wrapper = createWrapper({ histories: [] });
      expect(wrapper.vm.prettifyObjects("simple")).toBe("simple");
      expect(wrapper.vm.prettifyObjects(42)).toBe(42);
    });
  });
});
