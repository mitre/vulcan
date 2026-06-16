/**
 * RuleFormGroup — Lock Button + Right-Aligned Actions
 *
 * REQUIREMENTS:
 * - Label text + tooltip left-aligned, actions right-aligned
 * - Lock button: outlined, small, with lock/unlock icon
 *   - Unlocked + active: outline-success, clickable
 *   - Locked + active: outline-warning, clickable
 *   - Inactive (canManageSectionLocks=false): disabled
 *   - Hidden when showSectionLocks=false and canManageSectionLocks=false
 * - Emits toggle-section-lock when active lock button clicked
 */
import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleFormGroup from "@/components/shared/RuleFormGroup.vue";

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
      SectionCommentIcon: true,
      InfoTooltip: true,
    },
  });
}

function findLockBtn(wrapper) {
  return wrapper.find("[data-test=section-lock-btn]");
}

describe("RuleFormGroup", () => {
  let wrapper;

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  // ─── Layout ─────────────────────────────────────────────
  it("renders action bar below the label", () => {
    wrapper = createWrapper({
      showSectionLocks: true,
      canManageSectionLocks: true,
      lockedSections: {},
    });
    const bar = wrapper.find(".rfg-action-bar");
    expect(bar.exists()).toBe(true);
    expect(bar.classes()).toContain("rfg-action-bar");
  });

  // ─── Lock button: unlocked + active = outline-success ───
  it("unlocked active lock button has outline-success variant", () => {
    wrapper = createWrapper({
      showSectionLocks: true,
      canManageSectionLocks: true,
      lockedSections: {},
    });
    const btn = findLockBtn(wrapper);
    expect(btn.exists()).toBe(true);
    expect(btn.attributes("class")).toContain("btn-outline-success");
    expect(btn.attributes("disabled")).toBeUndefined();
  });

  // ─── Lock button: locked + active = outline-warning ─────
  it("locked active lock button has outline-warning variant", () => {
    wrapper = createWrapper({
      showSectionLocks: true,
      canManageSectionLocks: true,
      lockedSections: { General: true },
    });
    const btn = findLockBtn(wrapper);
    expect(btn.exists()).toBe(true);
    expect(btn.attributes("class")).toContain("btn-outline-warning");
  });

  // ─── Lock button: inactive = disabled ───────────────────
  it("disabled lock button when canManageSectionLocks is false", () => {
    wrapper = createWrapper({
      showSectionLocks: true,
      canManageSectionLocks: false,
      lockedSections: {},
    });
    const btn = findLockBtn(wrapper);
    expect(btn.exists()).toBe(true);
    expect(btn.attributes("disabled")).toBeDefined();
  });

  // ─── Lock button: hidden when both false ────────────────
  it("no lock button when showSectionLocks and canManageSectionLocks are both false", () => {
    wrapper = createWrapper({
      showSectionLocks: false,
      canManageSectionLocks: false,
      lockedSections: {},
    });
    expect(findLockBtn(wrapper).exists()).toBe(false);
  });

  // ─── Click behavior ────────────────────────────────────
  it("emits toggle-section-lock when active lock button is clicked", async () => {
    wrapper = createWrapper({
      showSectionLocks: true,
      canManageSectionLocks: true,
      lockedSections: {},
    });
    await findLockBtn(wrapper).trigger("click");
    expect(wrapper.emitted("toggle-section-lock")).toBeTruthy();
    expect(wrapper.emitted("toggle-section-lock")[0]).toEqual(["General"]);
  });

  it("does NOT emit toggle-section-lock when disabled lock button is clicked", async () => {
    wrapper = createWrapper({
      showSectionLocks: true,
      canManageSectionLocks: false,
      lockedSections: {},
    });
    await findLockBtn(wrapper).trigger("click");
    expect(wrapper.emitted("toggle-section-lock")).toBeFalsy();
  });
});
