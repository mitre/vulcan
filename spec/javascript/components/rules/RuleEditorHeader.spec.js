import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleEditorHeader from "@/components/rules/RuleEditorHeader.vue";

// Mock axios with defaults structure for FormMixin
vi.mock("axios", () => ({
  default: {
    post: vi.fn(() => Promise.resolve({ data: {} })),
    put: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: {
      headers: {
        common: {},
      },
    },
  },
}));

describe("RuleEditorHeader", () => {
  let wrapper;
  const mockRules = [
    {
      id: 1,
      rule_id: "001",
      version: "SV-001r1",
      component_id: 10,
      status: "Not Yet Determined",
      satisfies: [],
      satisfied_by: [],
      histories: [],
      locked: false,
      review_requestor_id: null,
      changes_requested: false,
      disa_rule_descriptions_attributes: [{ mitigations: "" }],
      created_at: "2024-01-01",
      updated_at: "2024-01-01",
      artifact_description: "",
    },
    {
      id: 2,
      rule_id: "002",
      version: "SV-002r1",
      component_id: 10,
      status: "Not Yet Determined",
      satisfies: [],
      satisfied_by: [],
    },
  ];

  const createWrapper = (props = {}) => {
    return shallowMount(RuleEditorHeader, {
      localVue,
      propsData: {
        effectivePermissions: "admin",
        currentUserId: 1,
        rule: mockRules[0],
        rules: mockRules,
        projectPrefix: "TEST",
        readOnly: false,
        ...props,
      },
      stubs: {
        CommentModal: true,
        NewRuleModalForm: true,
      },
    });
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  describe("header display", () => {
    it("displays project prefix and rule ID in header link", () => {
      wrapper = createWrapper();
      const link = wrapper.find("a.headerLink");
      expect(link.text()).toContain("TEST-001");
      expect(link.text()).toContain("SV-001r1");
    });

    it("shows lock icon when rule is locked", () => {
      wrapper = createWrapper({
        rule: { ...mockRules[0], locked: true },
      });
      expect(wrapper.find("[icon='lock']").exists()).toBe(true);
    });

    it("shows review icon when rule is under review", () => {
      wrapper = createWrapper({
        rule: { ...mockRules[0], review_requestor_id: 42 },
      });
      expect(wrapper.find("[icon='file-earmark-search']").exists()).toBe(true);
    });

    it("shows created date when no histories exist", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Created on");
    });
  });

  describe("locked/under review state", () => {
    it("disables save and delete buttons when rule is locked", () => {
      wrapper = createWrapper({
        rule: { ...mockRules[0], locked: true },
      });
      const disabledButtons = wrapper.findAll("b-button-stub[disabled]");
      expect(disabledButtons.length).toBeGreaterThanOrEqual(2);
    });

    it("shows locked warning message", () => {
      wrapper = createWrapper({
        rule: { ...mockRules[0], locked: true },
      });
      expect(wrapper.text()).toContain("locked and must first be unlocked");
    });

    it("shows under review warning message", () => {
      wrapper = createWrapper({
        rule: { ...mockRules[0], review_requestor_id: 42 },
      });
      expect(wrapper.text()).toContain("under review and cannot be edited");
    });
  });

  describe("review actions", () => {
    it("provides all six review action options", () => {
      wrapper = createWrapper();
      const actions = wrapper.vm.reviewActions;
      expect(actions).toHaveLength(6);
      expect(actions.map((a) => a.value)).toEqual([
        "request_review",
        "revoke_review_request",
        "request_changes",
        "approve",
        "lock_control",
        "unlock_control",
      ]);
    });

    it("disables lock when rule is already locked", () => {
      wrapper = createWrapper({
        rule: { ...mockRules[0], locked: true },
      });
      const lockAction = wrapper.vm.reviewActions.find((a) => a.value === "lock_control");
      expect(lockAction.disabledTooltip).toBeTruthy();
    });

    it("disables unlock when rule is not locked", () => {
      wrapper = createWrapper();
      const unlockAction = wrapper.vm.reviewActions.find((a) => a.value === "unlock_control");
      expect(unlockAction.disabledTooltip).toBeTruthy();
    });
  });

  describe("readOnly mode", () => {
    it("hides action buttons when readOnly is true", () => {
      wrapper = createWrapper({ readOnly: true });
      // The entire action section is v-if="!readOnly"
      expect(wrapper.find("b-button-stub[variant='info']").exists()).toBe(false);
    });
  });
});
