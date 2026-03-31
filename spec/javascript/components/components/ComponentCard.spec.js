import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ComponentCard from "@/components/components/ComponentCard.vue";

// Mock axios
vi.mock("axios", () => ({
  default: {
    defaults: { headers: { common: {} } },
  },
}));

/**
 * ComponentCard Requirements
 *
 * REQUIREMENTS:
 *
 * 1. COMPONENT INFO DISPLAY:
 *    - Name and version/release
 *    - Based on SRG title
 *    - Description (if present)
 *    - PoC name and email
 *    - Rules count badge
 *    - Released badge (if released)
 *
 * 2. PRIMARY ACTION:
 *    - "Open Component" button (always visible)
 *    - Links to component view page
 *
 * 3. NO EXPORT DROPDOWN:
 *    - Export removed - users use project-level Download instead
 *
 * 4. ADMIN ACTIONS (icon buttons with tooltips):
 *    - Lock: Lock all rules in component (reviewer+)
 *    - Duplicate: Create copy of component (admin)
 *    - Release: Mark component as released (admin, only if releasable)
 *    - Delete: Remove from project (admin)
 *
 * 5. DELETE CONFIRMATION:
 *    - Shows overlay with confirmation
 *    - Shows spinner while deleting
 *    - Emits deleteComponent event
 *
 * 6. OVERLAID INDICATOR:
 *    - Shows "(Overlaid)" badge if component_id present
 */
describe("ComponentCard", () => {
  let wrapper;

  const defaultComponent = {
    id: 1,
    name: "Test Component",
    version: "1",
    release: "1",
    released: false,
    releasable: true,
    rules_count: 10,
    component_id: null,
    based_on_title: "Test SRG",
    based_on_version: "V1R1",
    description: "Test description",
    admin_name: "Test Admin",
    admin_email: "admin@test.com",
    project_id: 5,
  };

  const createWrapper = (props = {}) => {
    return mount(ComponentCard, {
      localVue,
      propsData: {
        component: defaultComponent,
        effectivePermissions: "admin",
        ...props,
      },
      stubs: {
        LockControlsModal: true,
        NewComponentModal: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // ==========================================
  // COMPONENT INFO DISPLAY
  // ==========================================
  describe("component information", () => {
    it("displays component name", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Test Component");
    });

    it("displays version and release", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("v1");
      expect(wrapper.text()).toContain("r1");
    });

    it("displays based on SRG", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Test SRG");
      expect(wrapper.text()).toContain("V1R1");
    });

    it("displays description when present", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Test description");
    });

    it("displays PoC information", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Test Admin");
      expect(wrapper.text()).toContain("admin@test.com");
    });

    it('shows "No Component Admin" when admin not set', () => {
      const compWithoutAdmin = { ...defaultComponent, admin_name: null, admin_email: null };
      wrapper = createWrapper({ component: compWithoutAdmin });
      expect(wrapper.text()).toContain("No Component Admin");
    });

    it("displays rules count badge", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("10");
    });

    it("shows overlaid indicator when component_id present", () => {
      const overlaidComp = { ...defaultComponent, component_id: 999 };
      wrapper = createWrapper({ component: overlaidComp });
      expect(wrapper.text()).toContain("Overlaid");
    });

    it("shows released indicator when component is released", () => {
      const releasedComp = { ...defaultComponent, released: true };
      wrapper = createWrapper({ component: releasedComp });
      // Patch-check-fill icon should exist when released
      const html = wrapper.html();
      expect(html).toContain("patch-check-fill");
    });

    it("does NOT show released indicator when component is not released", () => {
      const unreleasedComp = { ...defaultComponent, released: false };
      wrapper = createWrapper({ component: unreleasedComp });
      const html = wrapper.html();
      expect(html).not.toContain("patch-check-fill");
    });
  });

  // ==========================================
  // PRIMARY ACTION
  // ==========================================
  describe("open component button", () => {
    it("renders Open Component button", () => {
      wrapper = createWrapper();
      const btn = wrapper.find('a[href="/components/1"]');
      expect(btn.exists()).toBe(true);
      expect(btn.text()).toContain("Open Component");
    });
  });

  // ==========================================
  // EXPORT REMOVED
  // ==========================================
  describe("export functionality removed (use project Download)", () => {
    it("does NOT render Export dropdown", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).not.toMatch(/Export/i);
    });

    it("does NOT have CSV export option", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).not.toContain("CSV");
    });

    it("does NOT have InSpec export option", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).not.toContain("InSpec");
    });

    it("does NOT have XCCDF export option", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).not.toContain("XCCDF");
    });
  });

  // ==========================================
  // ADMIN ACTION BUTTONS (Icon + Text for consistency)
  // ==========================================
  describe("admin action buttons with labels", () => {
    it("shows Lock button with icon and text for reviewer+", () => {
      wrapper = createWrapper({ effectivePermissions: "reviewer" });
      expect(wrapper.findComponent({ name: "LockControlsModal" }).exists()).toBe(true);
      // Button should have text label, not just tooltip
      expect(wrapper.text()).toContain("Lock");
    });

    it("shows Duplicate button with icon and text for admin", () => {
      wrapper = createWrapper({ effectivePermissions: "admin" });
      expect(wrapper.findAllComponents({ name: "NewComponentModal" }).length).toBeGreaterThan(0);
      expect(wrapper.text()).toContain("Duplicate");
    });

    it("shows Release button with icon and text for admin when releasable", () => {
      wrapper = createWrapper({
        effectivePermissions: "admin",
        component: { ...defaultComponent, releasable: true, released: false },
      });
      expect(wrapper.text()).toContain("Release");
    });

    it("shows Delete button with icon and text for admin", () => {
      wrapper = createWrapper({ effectivePermissions: "admin" });
      expect(wrapper.text()).toContain("Delete");
    });

    it("disables Release button when not releasable", () => {
      wrapper = createWrapper({
        effectivePermissions: "admin",
        component: { ...defaultComponent, releasable: false },
      });
      const releaseBtn = wrapper
        .findAll("button")
        .wrappers.find((b) => b.text().includes("Release"));
      expect(releaseBtn.attributes("disabled")).toBeDefined();
    });

    it("hides admin actions for non-admin users", () => {
      wrapper = createWrapper({
        effectivePermissions: "viewer",
        component: { ...defaultComponent, id: 1 },
      });
      // Should not show Delete button text
      expect(wrapper.text()).not.toContain("Delete");
    });

    it("action buttons are in a flex container for visual consistency", () => {
      wrapper = createWrapper({ effectivePermissions: "admin" });
      // Actions should be in a flex container with gap for consistent spacing
      const actionsContainer = wrapper.find(".d-flex.align-items-center.flex-wrap");
      expect(actionsContainer.exists()).toBe(true);
    });
  });

  // ==========================================
  // DELETE CONFIRMATION
  // ==========================================
  describe("delete confirmation workflow", () => {
    it("shows delete confirmation overlay when delete clicked", async () => {
      wrapper = createWrapper({ effectivePermissions: "admin" });
      expect(wrapper.vm.showDeleteConfirmation).toBe(false);

      const deleteBtn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("Delete"));
      await deleteBtn.trigger("click");

      expect(wrapper.vm.showDeleteConfirmation).toBe(true);
    });

    it("shows spinner when delete is confirmed", async () => {
      wrapper = createWrapper({ effectivePermissions: "admin" });
      wrapper.vm.showDeleteConfirmation = true;

      wrapper.vm.confirmDelete();

      expect(wrapper.vm.isDeleting).toBe(true);
    });

    it("emits deleteComponent with component id when confirmed", () => {
      wrapper = createWrapper({ effectivePermissions: "admin" });
      wrapper.vm.confirmDelete();

      expect(wrapper.emitted("deleteComponent")).toBeTruthy();
      expect(wrapper.emitted("deleteComponent")[0]).toEqual([1]);
    });

    it("resets isDeleting when delete fails", async () => {
      // REQUIREMENT: If the parent's delete operation fails, the card must
      // exit the "Removing..." spinner state so the user can retry or cancel.
      wrapper = createWrapper({ effectivePermissions: "admin" });
      wrapper.vm.confirmDelete();
      expect(wrapper.vm.isDeleting).toBe(true);

      // Simulate parent signaling failure via resetDelete method
      wrapper.vm.resetDelete();
      expect(wrapper.vm.isDeleting).toBe(false);
      expect(wrapper.vm.showDeleteConfirmation).toBe(false);
    });
  });
});
