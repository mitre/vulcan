/**
 * RuleFormGroup — Lock Icon Color Tests
 *
 * REQUIREMENTS:
 * - Unlocked + active (canManageSectionLocks=true, not locked): GREEN (text-success), clickable
 * - Locked + active (canManageSectionLocks=true, locked): ORANGE/WARNING (text-warning), clickable
 * - Disabled/inactive (showSectionLocks=true, canManageSectionLocks=false): GRAY (text-muted opacity-50), not clickable
 * - Icons hidden entirely when showSectionLocks=false and canManageSectionLocks=false
 */
import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleFormGroup from "@/components/shared/RuleFormGroup.vue";

// Mock the FIELD_TO_SECTION import so resolvedSection works
vi.mock("@/composables/ruleFieldConfig", () => ({
  FIELD_TO_SECTION: {
    title: "General",
    fixtext: "Fix",
  },
}));

function createWrapper(props = {}) {
  return mount(RuleFormGroup, {
    localVue,
    propsData: {
      fieldName: "title",
      label: "Title",
      fields: { displayed: ["title"], disabled: [] },
      ...props,
    },
    stubs: {
      "b-form-group": {
        template: "<div><slot /></div>",
        props: ["id"],
      },
      "b-icon": {
        template:
          '<span :class="$attrs.class" :icon="icon" @click="$listeners.click && $listeners.click($event)"></span>',
        props: ["icon"],
      },
      "b-form-valid-feedback": { template: "<span />" },
      "b-form-invalid-feedback": { template: "<span />" },
    },
  });
}

function findLockIcon(wrapper) {
  const icons = wrapper.findAllComponents({ name: "b-icon" });
  return icons.wrappers.find(
    (w) => w.props("icon") === "lock-fill" || w.props("icon") === "unlock",
  );
}

describe("RuleFormGroup lock icon colors", () => {
  let wrapper;

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  // ─── Unlocked + active = GREEN ───────────────────────────
  it("unlocked active icon has text-success and clickable class", () => {
    wrapper = createWrapper({
      showSectionLocks: true,
      canManageSectionLocks: true,
      lockedSections: {},
    });
    const icon = findLockIcon(wrapper);
    expect(icon).toBeTruthy();
    expect(icon.props("icon")).toBe("unlock");
    expect(icon.attributes("class")).toContain("text-success");
    expect(icon.attributes("class")).toContain("clickable");
    expect(icon.attributes("class")).not.toContain("opacity-50");
  });

  // ─── Locked + active = WARNING/ORANGE ────────────────────
  it("locked active icon has text-warning and clickable class", () => {
    wrapper = createWrapper({
      showSectionLocks: true,
      canManageSectionLocks: true,
      lockedSections: { General: true },
    });
    const icon = findLockIcon(wrapper);
    expect(icon).toBeTruthy();
    expect(icon.props("icon")).toBe("lock-fill");
    expect(icon.attributes("class")).toContain("text-warning");
    expect(icon.attributes("class")).toContain("clickable");
  });

  // ─── Disabled/inactive = GRAY + opacity ──────────────────
  it("disabled unlocked icon has text-muted opacity-50 and no clickable", () => {
    wrapper = createWrapper({
      showSectionLocks: true,
      canManageSectionLocks: false,
      lockedSections: {},
    });
    const icon = findLockIcon(wrapper);
    expect(icon).toBeTruthy();
    expect(icon.props("icon")).toBe("unlock");
    expect(icon.attributes("class")).toContain("text-muted");
    expect(icon.attributes("class")).toContain("opacity-50");
    expect(icon.attributes("class")).not.toContain("clickable");
    expect(icon.attributes("class")).not.toContain("text-success");
  });

  it("disabled locked icon has text-muted and no clickable", () => {
    wrapper = createWrapper({
      showSectionLocks: true,
      canManageSectionLocks: false,
      lockedSections: { General: true },
    });
    const icon = findLockIcon(wrapper);
    expect(icon).toBeTruthy();
    expect(icon.props("icon")).toBe("lock-fill");
    expect(icon.attributes("class")).toContain("text-muted");
    expect(icon.attributes("class")).not.toContain("clickable");
    expect(icon.attributes("class")).not.toContain("text-warning");
  });

  // ─── Hidden when both false ──────────────────────────────
  it("no lock icon when showSectionLocks and canManageSectionLocks are both false", () => {
    wrapper = createWrapper({
      showSectionLocks: false,
      canManageSectionLocks: false,
      lockedSections: {},
    });
    const icon = findLockIcon(wrapper);
    expect(icon).toBeUndefined();
  });

  // ─── Click behavior ──────────────────────────────────────
  it("emits toggle-section-lock when active icon is clicked", async () => {
    wrapper = createWrapper({
      showSectionLocks: true,
      canManageSectionLocks: true,
      lockedSections: {},
    });
    const icon = findLockIcon(wrapper);
    await icon.trigger("click");
    expect(wrapper.emitted("toggle-section-lock")).toBeTruthy();
    expect(wrapper.emitted("toggle-section-lock")[0]).toEqual(["General"]);
  });

  it("does NOT emit toggle-section-lock when disabled icon is clicked", async () => {
    wrapper = createWrapper({
      showSectionLocks: true,
      canManageSectionLocks: false,
      lockedSections: {},
    });
    const icon = findLockIcon(wrapper);
    await icon.trigger("click");
    expect(wrapper.emitted("toggle-section-lock")).toBeFalsy();
  });
});
