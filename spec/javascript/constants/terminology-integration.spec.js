import { describe, it, expect } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import { RULE_TERM, MESSAGE_LABELS } from "@/constants/terminology";

/**
 * Integration tests to verify terminology constants are used consistently
 * across all components. These tests ensure DRY principle is maintained.
 *
 * TDD: Write these tests FIRST, watch them FAIL, then implement.
 */

describe("Terminology Integration - ComponentCard", () => {
  it("uses ruleCountLabel for displaying rule counts", async () => {
    const ComponentCard = (await import("@/components/components/ComponentCard.vue")).default;

    const wrapper = shallowMount(ComponentCard, {
      localVue,
      propsData: {
        component: {
          id: 1,
          name: "Test Component",
          rules_count: 5,
          based_on: "Test SRG",
          prefix: "TEST",
          admin_name: "Admin",
          admin_email: "admin@test.com",
          memberships: [],
        },
        effectivePermissions: "viewer",
      },
      stubs: ["router-link", "LockControlsModal"],
    });

    // Should use RULE_TERM.plural (Rules), not hardcoded "Controls"
    expect(wrapper.text()).toContain(`5 ${RULE_TERM.plural}`);
  });

  it("uses singular for count of 1", async () => {
    const ComponentCard = (await import("@/components/components/ComponentCard.vue")).default;

    const wrapper = shallowMount(ComponentCard, {
      localVue,
      propsData: {
        component: {
          id: 1,
          name: "Test Component",
          rules_count: 1,
          based_on: "Test SRG",
          prefix: "TEST",
          admin_name: "Admin",
          admin_email: "admin@test.com",
          memberships: [],
        },
        effectivePermissions: "viewer",
      },
      stubs: ["router-link", "LockControlsModal"],
    });

    // Should use RULE_TERM.singular (Rule), not hardcoded "Control"
    expect(wrapper.text()).toContain(`1 ${RULE_TERM.singular}`);
  });
});

describe("Terminology Integration - LockControlsModal", () => {
  it("uses MESSAGE_LABELS.lockAllTitle for modal title", async () => {
    const LockControlsModal = (await import("@/components/components/LockControlsModal.vue"))
      .default;

    const wrapper = shallowMount(LockControlsModal, {
      localVue,
      propsData: {
        component_id: 1,
      },
    });

    // Modal title should use MESSAGE_LABELS.lockAllTitle
    // Currently hardcoded as "Lock Component Controls", should be "Lock Component Rules"
    expect(wrapper.text()).toContain(MESSAGE_LABELS.lockAllTitle);
  });

  it("uses RULE_TERM.plural in button text (not hardcoded Controls)", async () => {
    const LockControlsModal = (await import("@/components/components/LockControlsModal.vue"))
      .default;

    const wrapper = shallowMount(LockControlsModal, {
      localVue,
      propsData: {
        component_id: 1,
      },
    });

    // Button text should contain RULE_TERM.plural (Rules), not "Controls"
    expect(wrapper.text()).toContain(RULE_TERM.plural);
    expect(wrapper.text()).not.toContain("Controls");
  });
});

// RuleEditorHeader requires complex setup with rules array - will update component directly
// and verify manually. The component uses hardcoded strings that need to be DRY'd.
