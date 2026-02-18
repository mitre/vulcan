import { describe, it, expect, afterEach, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import axios from "axios";
import RestoreBackupModal from "@/components/project/RestoreBackupModal.vue";

vi.mock("axios");

/**
 * RestoreBackupModal - Upload JSON archive ZIP to restore components
 *
 * REQUIREMENTS:
 *
 * 1. UPLOAD STEP:
 *    - File input accepting .zip files
 *    - "Include review history" checkbox (checked by default)
 *    - "Preview Import" button (disabled until file selected)
 *    - Sends dry_run=true POST to /projects/:id/import_backup
 *
 * 2. PREVIEW STEP:
 *    - Shows summary counts (components, rules, satisfactions, reviews)
 *    - Shows warnings if any
 *    - "Import" button to confirm
 *    - "Back" button to return to upload
 *
 * 3. ON SUCCESS:
 *    - Shows toast notification
 *    - Emits projectUpdated
 *    - Closes modal
 *
 * 4. ON ERROR:
 *    - Shows error toast
 *    - Stays on current step
 */
describe("RestoreBackupModal", () => {
  let wrapper;

  const PROJECT_ID = 42;

  const MOCK_DRY_RUN_RESPONSE = {
    data: {
      toast: "Dry run complete. No records were created.",
      summary: {
        components_imported: 2,
        rules_imported: 94,
        satisfactions_imported: 12,
        reviews_imported: 8,
      },
      warnings: [],
    },
  };

  const MOCK_IMPORT_RESPONSE = {
    data: {
      toast: "Backup restored successfully.",
      summary: {
        components_imported: 2,
        rules_imported: 94,
        satisfactions_imported: 12,
        reviews_imported: 8,
      },
      warnings: [],
    },
  };

  const createWrapper = (props = {}) => {
    return mount(RestoreBackupModal, {
      localVue,
      propsData: {
        project_id: PROJECT_ID,
        ...props,
      },
      stubs: {
        "b-modal": {
          template: `
            <div v-if="value" class="modal">
              <div class="modal-title">{{ title }}</div>
              <div class="modal-body"><slot></slot></div>
              <div class="modal-footer"><slot name="modal-footer"></slot></div>
            </div>
          `,
          props: ["value", "title", "size", "centered"],
          model: { prop: "value", event: "input" },
        },
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

  // ==========================================
  // UPLOAD STEP RENDERING
  // ==========================================
  describe("upload step", () => {
    it("renders file input accepting .zip files", async () => {
      wrapper = createWrapper();
      wrapper.vm.showModal();
      await wrapper.vm.$nextTick();

      const fileInput = wrapper.find('[data-testid="backup-file-input"]');
      expect(fileInput.exists()).toBe(true);
    });

    it("renders include-reviews checkbox checked by default", async () => {
      wrapper = createWrapper();
      wrapper.vm.showModal();
      await wrapper.vm.$nextTick();

      const checkbox = wrapper.find('[data-testid="include-reviews-checkbox"]');
      expect(checkbox.exists()).toBe(true);
      expect(wrapper.vm.includeReviews).toBe(true);
    });

    it("preview button is disabled when no file selected", async () => {
      wrapper = createWrapper();
      wrapper.vm.showModal();
      await wrapper.vm.$nextTick();

      const previewBtn = wrapper.find('[data-testid="preview-btn"]');
      expect(previewBtn.exists()).toBe(true);
      expect(previewBtn.attributes("disabled")).toBeDefined();
    });

    it("preview button is enabled when file selected", async () => {
      wrapper = createWrapper();
      wrapper.vm.showModal();
      await wrapper.vm.$nextTick();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });
      await wrapper.vm.$nextTick();

      const previewBtn = wrapper.find('[data-testid="preview-btn"]');
      expect(previewBtn.attributes("disabled")).toBeUndefined();
    });
  });

  // ==========================================
  // DRY RUN (PREVIEW)
  // ==========================================
  describe("dry run", () => {
    it("calls dry-run endpoint with correct params", async () => {
      axios.post.mockResolvedValue(MOCK_DRY_RUN_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();

      const testFile = new File(["test"], "backup.zip", { type: "application/zip" });
      wrapper.vm.file = testFile;
      await wrapper.vm.$nextTick();

      await wrapper.vm.submitDryRun();

      expect(axios.post).toHaveBeenCalledWith(
        `/projects/${PROJECT_ID}/import_backup`,
        expect.any(FormData),
        expect.objectContaining({
          headers: { "Content-Type": "multipart/form-data" },
        }),
      );

      // Verify FormData contents
      const formData = axios.post.mock.calls[0][1];
      expect(formData.get("dry_run")).toBe("true");
      expect(formData.get("include_reviews")).toBe("true");
      expect(formData.get("file")).toBeTruthy();
    });

    it("moves to preview step on successful dry-run", async () => {
      axios.post.mockResolvedValue(MOCK_DRY_RUN_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });

      await wrapper.vm.submitDryRun();

      expect(wrapper.vm.step).toBe("preview");
      expect(wrapper.vm.summary).toEqual(MOCK_DRY_RUN_RESPONSE.data.summary);
    });

    it("shows summary counts in preview step", async () => {
      axios.post.mockResolvedValue(MOCK_DRY_RUN_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });

      await wrapper.vm.submitDryRun();
      await wrapper.vm.$nextTick();

      expect(wrapper.text()).toContain("2");
      expect(wrapper.text()).toContain("94");
      expect(wrapper.text()).toContain("12");
      expect(wrapper.text()).toContain("8");
    });

    it("shows warnings from dry-run", async () => {
      const responseWithWarnings = {
        data: {
          ...MOCK_DRY_RUN_RESPONSE.data,
          warnings: ["User john@example.com not found, skipping 3 reviews"],
        },
      };
      axios.post.mockResolvedValue(responseWithWarnings);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });

      await wrapper.vm.submitDryRun();
      await wrapper.vm.$nextTick();

      expect(wrapper.text()).toContain("john@example.com not found");
    });

    it("stays on upload step on dry-run error", async () => {
      axios.post.mockRejectedValue({
        response: {
          data: {
            toast: { title: "Import failed", message: "Invalid ZIP", variant: "danger" },
          },
        },
      });
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });

      await wrapper.vm.submitDryRun();

      expect(wrapper.vm.step).toBe("upload");
    });
  });

  // ==========================================
  // IMPORT (CONFIRM)
  // ==========================================
  describe("import", () => {
    it("calls real endpoint with dry_run=false", async () => {
      axios.post.mockResolvedValue(MOCK_IMPORT_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });
      wrapper.vm.step = "preview";
      wrapper.vm.summary = MOCK_DRY_RUN_RESPONSE.data.summary;

      await wrapper.vm.submitImport();

      const formData = axios.post.mock.calls[0][1];
      expect(formData.get("dry_run")).toBe("false");
    });

    it("emits projectUpdated on successful import", async () => {
      axios.post.mockResolvedValue(MOCK_IMPORT_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });
      wrapper.vm.step = "preview";
      wrapper.vm.summary = MOCK_DRY_RUN_RESPONSE.data.summary;

      await wrapper.vm.submitImport();

      expect(wrapper.emitted("projectUpdated")).toBeTruthy();
    });

    it("closes modal on successful import", async () => {
      axios.post.mockResolvedValue(MOCK_IMPORT_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });
      wrapper.vm.step = "preview";
      wrapper.vm.summary = MOCK_DRY_RUN_RESPONSE.data.summary;

      await wrapper.vm.submitImport();

      expect(wrapper.vm.modalShow).toBe(false);
    });
  });

  // ==========================================
  // NAVIGATION
  // ==========================================
  describe("navigation", () => {
    it("back button returns to upload step", async () => {
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.step = "preview";
      wrapper.vm.summary = MOCK_DRY_RUN_RESPONSE.data.summary;
      await wrapper.vm.$nextTick();

      const backBtn = wrapper.find('[data-testid="back-btn"]');
      await backBtn.trigger("click");

      expect(wrapper.vm.step).toBe("upload");
    });

    it("resets state when modal reopened", async () => {
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });
      wrapper.vm.step = "preview";
      wrapper.vm.summary = { components_imported: 5 };

      // Close and reopen
      wrapper.vm.modalShow = false;
      wrapper.vm.showModal();

      expect(wrapper.vm.step).toBe("upload");
      expect(wrapper.vm.file).toBe(null);
      expect(wrapper.vm.summary).toBe(null);
      expect(wrapper.vm.includeReviews).toBe(true);
    });
  });

  // ==========================================
  // INCLUDE REVIEWS
  // ==========================================
  describe("include reviews", () => {
    it("sends include_reviews=false when unchecked", async () => {
      axios.post.mockResolvedValue(MOCK_DRY_RUN_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });
      wrapper.vm.includeReviews = false;

      await wrapper.vm.submitDryRun();

      const formData = axios.post.mock.calls[0][1];
      expect(formData.get("include_reviews")).toBe("false");
    });
  });

  // ==========================================
  // COMPONENT PICKER (preview step)
  // ==========================================
  describe("component picker", () => {
    const MOCK_DRY_RUN_WITH_DETAILS = {
      data: {
        toast: "Dry run complete.",
        summary: {
          components_imported: 2,
          rules_imported: 94,
          satisfactions_imported: 12,
          reviews_imported: 8,
          component_details: [
            { name: "Component A", rule_count: 50, conflict: false },
            { name: "Component B", rule_count: 44, conflict: true },
          ],
        },
        warnings: [],
      },
    };

    const setupPreviewWithDetails = async () => {
      axios.post.mockResolvedValue(MOCK_DRY_RUN_WITH_DETAILS);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });
      await wrapper.vm.submitDryRun();
      await wrapper.vm.$nextTick();
    };

    it("shows component checkboxes when component_details present", async () => {
      await setupPreviewWithDetails();
      const picker = wrapper.find('[data-testid="component-picker"]');
      expect(picker.exists()).toBe(true);
      const rows = wrapper.findAll('[data-testid="component-row"]');
      expect(rows.length).toBe(2);
    });

    it("all components selected by default", async () => {
      await setupPreviewWithDetails();
      expect(wrapper.vm.componentSelections.every((c) => c.selected)).toBe(true);
    });

    it("conflicting component gets auto-renamed import name", async () => {
      await setupPreviewWithDetails();
      const conflicting = wrapper.vm.componentSelections.find((c) => c.conflict);
      expect(conflicting.importName).toBe("Component B (restored)");
    });

    it("shows conflict badge for conflicting components", async () => {
      await setupPreviewWithDetails();
      const badges = wrapper.findAll('[data-testid="conflict-badge"]');
      expect(badges.length).toBe(1);
    });

    it("conflicting component name is editable when selected", async () => {
      await setupPreviewWithDetails();
      const nameInput = wrapper.find('[data-testid="component-name-input-1"]');
      expect(nameInput.exists()).toBe(true);
    });

    it("summary updates based on selection", async () => {
      await setupPreviewWithDetails();
      // Deselect first component
      wrapper.vm.componentSelections[0].selected = false;
      await wrapper.vm.$nextTick();

      expect(wrapper.vm.selectedComponentCount).toBe(1);
      expect(wrapper.vm.selectedRuleCount).toBe(44);
    });

    it("sends component_filter JSON in FormData on import", async () => {
      await setupPreviewWithDetails();
      axios.post.mockResolvedValue({
        data: { toast: "Backup restored successfully." },
      });

      await wrapper.vm.submitImport();

      const formData = axios.post.mock.calls[1][1]; // second call (first was dry-run)
      const filter = JSON.parse(formData.get("component_filter"));
      expect(filter["Component A"]).toBe("Component A");
      expect(filter["Component B"]).toBe("Component B (restored)");
    });

    it("import button disabled when no components selected", async () => {
      await setupPreviewWithDetails();
      wrapper.vm.componentSelections.forEach((c) => (c.selected = false));
      await wrapper.vm.$nextTick();

      const importBtn = wrapper.find('[data-testid="import-btn"]');
      expect(importBtn.attributes("disabled")).toBeDefined();
    });

    it("does not show picker when component_details absent", async () => {
      // Use the standard dry-run response (no component_details)
      axios.post.mockResolvedValue(MOCK_DRY_RUN_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });
      await wrapper.vm.submitDryRun();
      await wrapper.vm.$nextTick();

      const picker = wrapper.find('[data-testid="component-picker"]');
      expect(picker.exists()).toBe(false);
    });
  });

  // ==========================================
  // INCLUDE MEMBERSHIPS
  // ==========================================
  describe("include memberships", () => {
    it("renders include-memberships checkbox unchecked by default", async () => {
      wrapper = createWrapper();
      wrapper.vm.showModal();
      await wrapper.vm.$nextTick();

      const checkbox = wrapper.find('[data-testid="include-memberships-checkbox"]');
      expect(checkbox.exists()).toBe(true);
      expect(wrapper.vm.includeMemberships).toBe(false);
    });

    it("sends include_memberships=false by default", async () => {
      axios.post.mockResolvedValue(MOCK_DRY_RUN_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });

      await wrapper.vm.submitDryRun();

      const formData = axios.post.mock.calls[0][1];
      expect(formData.get("include_memberships")).toBe("false");
    });

    it("sends include_memberships=true when checked", async () => {
      axios.post.mockResolvedValue(MOCK_DRY_RUN_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });
      wrapper.vm.includeMemberships = true;

      await wrapper.vm.submitDryRun();

      const formData = axios.post.mock.calls[0][1];
      expect(formData.get("include_memberships")).toBe("true");
    });

    it("resets to false when modal reopened", async () => {
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.includeMemberships = true;

      wrapper.vm.modalShow = false;
      wrapper.vm.showModal();

      expect(wrapper.vm.includeMemberships).toBe(false);
    });

    it("shows memberships row in preview when summary includes it", async () => {
      const responseWithMemberships = {
        data: {
          ...MOCK_DRY_RUN_RESPONSE.data,
          summary: {
            ...MOCK_DRY_RUN_RESPONSE.data.summary,
            memberships_imported: 5,
          },
        },
      };
      axios.post.mockResolvedValue(responseWithMemberships);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });

      await wrapper.vm.submitDryRun();
      await wrapper.vm.$nextTick();

      expect(wrapper.text()).toContain("Memberships");
      expect(wrapper.text()).toContain("5");
    });
  });
});
