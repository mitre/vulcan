import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import BackupPreview from "@/components/shared/BackupPreview.vue";

/**
 * BackupPreview — Shared preview component for backup restore modals
 *
 * REQUIREMENTS:
 *
 * 1. STAT CARDS:
 *    - Shows component count, rule count, satisfaction count at top
 *    - Updates dynamically when selectable components are toggled
 *
 * 2. COMPONENT LIST:
 *    - Read-only mode: displays component names with metadata (no checkboxes)
 *    - Selectable mode: checkboxes for each component, conflict badges, rename inputs
 *    - Per-component: name, rule count, SRG title/version
 *
 * 3. SRG AUTO-IMPORT ALERT:
 *    - Shows when srg_details present and non-empty
 *    - Lists each SRG with title and version
 *
 * 4. WARNINGS:
 *    - Rendered above everything else for visibility
 *    - Each warning in its own alert
 *
 * 5. SUMMARY TABLE:
 *    - Totals for rules, satisfactions, reviews
 *    - Conditional rows for memberships and SRGs
 *
 * 6. LIVE CONFLICT VALIDATION (selectable mode):
 *    - Badge reflects CURRENT import name state, not original conflict
 *    - "name taken" when importName matches an existing project component
 *    - "name taken" when importName duplicates another selected import
 *    - "name required" when importName is empty
 *    - "ready" (check icon) when importName is valid
 *    - Auto-renames conflicting components with "(restored)" suffix
 *    - Auto-focuses first conflicting input
 *    - hasUnresolvedConflicts emitted so parent can disable Import
 */
describe("BackupPreview", () => {
  let wrapper;

  const BASIC_SUMMARY = {
    components_imported: 2,
    rules_imported: 94,
    satisfactions_imported: 12,
    reviews_imported: 8,
  };

  const COMPONENT_DETAILS = [
    { name: "RHEL 9", rule_count: 50, conflict: false, srg_title: "GPOS SRG", srg_version: "V3R3" },
    {
      name: "Apache",
      rule_count: 44,
      conflict: true,
      srg_title: "Web Server SRG",
      srg_version: "V4R4",
    },
  ];

  const SRG_DETAILS = [{ srg_id: "SRG-001", title: "GPOS SRG", version: "V3R3" }];

  const createWrapper = (props = {}) => {
    return mount(BackupPreview, {
      localVue,
      propsData: {
        summary: BASIC_SUMMARY,
        componentDetails: [],
        warnings: [],
        ...props,
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  // ==========================================
  // STAT CARDS
  // ==========================================
  describe("stat cards", () => {
    it("renders component, rule, and satisfaction counts", () => {
      wrapper = createWrapper({ componentDetails: COMPONENT_DETAILS });

      const stats = wrapper.find('[data-testid="stat-cards"]');
      expect(stats.exists()).toBe(true);
      expect(stats.text()).toContain("2");
      expect(stats.text()).toContain("94");
      expect(stats.text()).toContain("12");
    });

    it("shows review count when non-zero", () => {
      wrapper = createWrapper();

      const stats = wrapper.find('[data-testid="stat-cards"]');
      expect(stats.text()).toContain("8");
    });

    it("shows membership count when present in summary", () => {
      wrapper = createWrapper({
        summary: { ...BASIC_SUMMARY, memberships_imported: 3 },
      });

      const stats = wrapper.find('[data-testid="stat-cards"]');
      expect(stats.text()).toContain("3");
    });

    it("updates counts based on component selection", async () => {
      wrapper = createWrapper({
        selectable: true,
        componentDetails: COMPONENT_DETAILS,
      });

      // Deselect first component
      const checkboxes = wrapper.findAll('[data-testid^="component-checkbox-"]');
      await checkboxes.at(0).find("input").setChecked(false);

      const stats = wrapper.find('[data-testid="stat-cards"]');
      // Should show 1 component, 44 rules (only Apache selected)
      expect(stats.text()).toContain("1");
      expect(stats.text()).toContain("44");
    });
  });

  // ==========================================
  // WARNINGS
  // ==========================================
  describe("warnings", () => {
    it("renders warnings above other content", () => {
      wrapper = createWrapper({
        warnings: ["User john@example.com not found"],
      });

      const warningAlert = wrapper.find('[data-testid="warning-alert"]');
      expect(warningAlert.exists()).toBe(true);
      expect(warningAlert.text()).toContain("john@example.com not found");
    });

    it("renders multiple warnings", () => {
      wrapper = createWrapper({
        warnings: ["Warning 1", "Warning 2"],
      });

      const alerts = wrapper.findAll('[data-testid="warning-alert"]');
      expect(alerts.length).toBe(2);
    });

    it("hides warnings section when empty", () => {
      wrapper = createWrapper({ warnings: [] });

      expect(wrapper.find('[data-testid="warning-alert"]').exists()).toBe(false);
    });
  });

  // ==========================================
  // COMPONENT LIST — READ-ONLY (default)
  // ==========================================
  describe("component list (read-only)", () => {
    it("shows component rows with name and rule count", () => {
      wrapper = createWrapper({ componentDetails: COMPONENT_DETAILS });

      const rows = wrapper.findAll('[data-testid="component-row"]');
      expect(rows.length).toBe(2);
      expect(rows.at(0).text()).toContain("RHEL 9");
      expect(rows.at(0).text()).toContain("50 rules");
    });

    it("shows Parent SRG label with title and version per component", () => {
      wrapper = createWrapper({ componentDetails: COMPONENT_DETAILS });

      const srgLabel = wrapper.findAll('[data-testid="parent-srg"]').at(0);
      expect(srgLabel.exists()).toBe(true);
      expect(srgLabel.text()).toContain("Parent SRG:");
      expect(srgLabel.text()).toContain("GPOS SRG");
      expect(srgLabel.text()).toContain("V3R3");
    });

    it("does not show checkboxes in read-only mode", () => {
      wrapper = createWrapper({ componentDetails: COMPONENT_DETAILS });

      expect(wrapper.find('[data-testid^="component-checkbox-"]').exists()).toBe(false);
    });

    it("hides component list when no details provided", () => {
      wrapper = createWrapper({ componentDetails: [] });

      expect(wrapper.find('[data-testid="component-list"]').exists()).toBe(false);
    });
  });

  // ==========================================
  // COMPONENT LIST — SELECTABLE
  // ==========================================
  describe("component list (selectable)", () => {
    it("shows checkboxes when selectable prop is true", () => {
      wrapper = createWrapper({
        selectable: true,
        componentDetails: COMPONENT_DETAILS,
      });

      const checkboxes = wrapper.findAll('[data-testid^="component-checkbox-"]');
      expect(checkboxes.length).toBe(2);
    });

    it("all components selected by default", () => {
      wrapper = createWrapper({
        selectable: true,
        componentDetails: COMPONENT_DETAILS,
      });

      expect(wrapper.vm.selections.every((s) => s.selected)).toBe(true);
    });

    it("auto-renames conflicting component with (restored) suffix", () => {
      wrapper = createWrapper({
        selectable: true,
        componentDetails: COMPONENT_DETAILS,
        existingNames: ["Apache"],
      });

      const conflicting = wrapper.vm.selections.find((s) => s.conflict);
      expect(conflicting.importName).toBe("Apache (restored)");
    });

    it("shows editable name input for selected conflicting component", () => {
      wrapper = createWrapper({
        selectable: true,
        componentDetails: COMPONENT_DETAILS,
        existingNames: ["Apache"],
      });

      const nameInput = wrapper.find('[data-testid="component-name-input-1"]');
      expect(nameInput.exists()).toBe(true);
    });

    it("shows ready status when conflict is resolved by rename", () => {
      wrapper = createWrapper({
        selectable: true,
        componentDetails: COMPONENT_DETAILS,
        existingNames: ["Apache"],
      });

      // "Apache (restored)" doesn't conflict — should show ready
      const row = wrapper.findAll('[data-testid="component-row"]').at(1);
      expect(row.find('[data-testid="status-ready"]').exists()).toBe(true);
      expect(row.find('[data-testid="status-name-taken"]').exists()).toBe(false);
    });

    it("shows name-taken status when import name matches existing", async () => {
      wrapper = createWrapper({
        selectable: true,
        componentDetails: COMPONENT_DETAILS,
        existingNames: ["Apache"],
      });

      // Change import name back to conflicting name
      wrapper.vm.selections[1].importName = "Apache";
      await wrapper.vm.$nextTick();

      const row = wrapper.findAll('[data-testid="component-row"]').at(1);
      expect(row.find('[data-testid="status-name-taken"]').exists()).toBe(true);
    });

    it("shows name-required status when import name is empty", async () => {
      wrapper = createWrapper({
        selectable: true,
        componentDetails: COMPONENT_DETAILS,
        existingNames: ["Apache"],
      });

      wrapper.vm.selections[1].importName = "";
      await wrapper.vm.$nextTick();

      const row = wrapper.findAll('[data-testid="component-row"]').at(1);
      expect(row.find('[data-testid="status-name-required"]').exists()).toBe(true);
    });

    it("detects duplicate import names across selections", async () => {
      const details = [
        { name: "Comp A", rule_count: 50, conflict: true },
        { name: "Comp B", rule_count: 44, conflict: true },
      ];
      wrapper = createWrapper({
        selectable: true,
        componentDetails: details,
        existingNames: ["Comp A", "Comp B"],
      });

      // Both auto-renamed to "(restored)" — set them to same name
      wrapper.vm.selections[0].importName = "Same Name";
      wrapper.vm.selections[1].importName = "Same Name";
      await wrapper.vm.$nextTick();

      // At least one should show duplicate error
      const duplicateBadges = wrapper.findAll('[data-testid="status-name-taken"]');
      expect(duplicateBadges.length).toBeGreaterThanOrEqual(1);
    });

    it("emits hasUnresolvedConflicts=false when all conflicts resolved", async () => {
      wrapper = createWrapper({
        selectable: true,
        componentDetails: COMPONENT_DETAILS,
        existingNames: ["Apache"],
      });

      // Force a real change: set to something different, then to resolved name
      wrapper.vm.selections[1].importName = "temp";
      await wrapper.vm.$nextTick();
      wrapper.vm.selections[1].importName = "Apache (restored)";
      await wrapper.vm.$nextTick();

      const emitted = wrapper.emitted("selection-change");
      const lastPayload = emitted[emitted.length - 1][0];
      expect(lastPayload.hasUnresolvedConflicts).toBe(false);
    });

    it("emits hasUnresolvedConflicts=true when conflict unresolved", async () => {
      wrapper = createWrapper({
        selectable: true,
        componentDetails: COMPONENT_DETAILS,
        existingNames: ["Apache"],
      });

      // Set back to conflicting name
      wrapper.vm.selections[1].importName = "Apache";
      await wrapper.vm.$nextTick();

      const emitted = wrapper.emitted("selection-change");
      const lastPayload = emitted[emitted.length - 1][0];
      expect(lastPayload.hasUnresolvedConflicts).toBe(true);
    });

    it("emits selection-change with component filter when selection changes", async () => {
      wrapper = createWrapper({
        selectable: true,
        componentDetails: COMPONENT_DETAILS,
        existingNames: ["Apache"],
      });

      // Deselect first component
      wrapper.vm.selections[0].selected = false;
      await wrapper.vm.$nextTick();

      const emitted = wrapper.emitted("selection-change");
      expect(emitted).toBeTruthy();
      const lastPayload = emitted[emitted.length - 1][0];
      expect(lastPayload.selectedCount).toBe(1);
      expect(lastPayload.selectedRuleCount).toBe(44);
      expect(lastPayload.componentFilter).toEqual({ Apache: "Apache (restored)" });
    });
  });

  // ==========================================
  // SRG IMPORT ALERT
  // ==========================================
  describe("SRG import alert", () => {
    it("shows SRG auto-import notice when srg_details present", () => {
      wrapper = createWrapper({
        summary: { ...BASIC_SUMMARY, srg_details: SRG_DETAILS, srgs_imported: 1 },
      });

      const alert = wrapper.find('[data-testid="srg-import-alert"]');
      expect(alert.exists()).toBe(true);
      expect(alert.text()).toContain("GPOS SRG");
      expect(alert.text()).toContain("V3R3");
    });

    it("hides SRG alert when no srg_details", () => {
      wrapper = createWrapper();

      expect(wrapper.find('[data-testid="srg-import-alert"]').exists()).toBe(false);
    });

    it("pluralizes correctly for multiple SRGs", () => {
      wrapper = createWrapper({
        summary: {
          ...BASIC_SUMMARY,
          srg_details: [
            ...SRG_DETAILS,
            { srg_id: "SRG-002", title: "Web Server SRG", version: "V4R4" },
          ],
          srgs_imported: 2,
        },
      });

      const alert = wrapper.find('[data-testid="srg-import-alert"]');
      expect(alert.text()).toContain("2 base SRGs");
    });
  });

  // ==========================================
  // SUMMARY TABLE
  // ==========================================
  describe("summary table", () => {
    it("shows rules, satisfactions, reviews rows", () => {
      wrapper = createWrapper();

      const table = wrapper.find('[data-testid="summary-table"]');
      expect(table.exists()).toBe(true);
      expect(table.text()).toContain("Rules");
      expect(table.text()).toContain("94");
      expect(table.text()).toContain("Satisfactions");
      expect(table.text()).toContain("12");
      expect(table.text()).toContain("Reviews");
      expect(table.text()).toContain("8");
    });

    it("shows memberships row when present", () => {
      wrapper = createWrapper({
        summary: { ...BASIC_SUMMARY, memberships_imported: 5 },
      });

      const table = wrapper.find('[data-testid="summary-table"]');
      expect(table.text()).toContain("Memberships");
      expect(table.text()).toContain("5");
    });

    it("hides memberships row when not present", () => {
      wrapper = createWrapper();

      const table = wrapper.find('[data-testid="summary-table"]');
      expect(table.text()).not.toContain("Memberships");
    });

    it("shows SRGs row when srgs_imported > 0", () => {
      wrapper = createWrapper({
        summary: { ...BASIC_SUMMARY, srgs_imported: 1, srg_details: SRG_DETAILS },
      });

      const table = wrapper.find('[data-testid="summary-table"]');
      expect(table.text()).toContain("SRGs to import");
    });
  });
});
