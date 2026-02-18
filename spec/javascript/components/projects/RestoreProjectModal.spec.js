import { describe, it, expect, afterEach, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import axios from "axios";
import RestoreProjectModal from "@/components/projects/RestoreProjectModal.vue";

vi.mock("axios");

/**
 * RestoreProjectModal - Create new project from backup archive
 *
 * REQUIREMENTS:
 *
 * 1. UPLOAD STEP:
 *    - File input accepting .zip files
 *    - Project name, description, visibility fields
 *    - Review and membership checkboxes
 *    - Preview button (disabled until file + name provided)
 *    - Sends dry_run=true POST to /projects/create_from_backup
 *
 * 2. PREVIEW STEP:
 *    - Pre-fills project name/description from archive
 *    - Shows summary counts
 *    - Shows warnings if any
 *    - "Create Project" button to confirm
 *    - "Back" button to return to upload
 *
 * 3. ON SUCCESS:
 *    - Redirects to new project page via globalThis.location
 */
describe("RestoreProjectModal", () => {
  let wrapper;

  const MOCK_DRY_RUN_RESPONSE = {
    data: {
      summary: {
        components_imported: 2,
        rules_imported: 94,
        satisfactions_imported: 12,
        reviews_imported: 8,
        component_details: [
          { name: "Photon OS 4", rule_count: 50 },
          { name: "RHEL 9", rule_count: 44 },
        ],
      },
      warnings: [],
      project_defaults: {
        name: "My Original Project",
        description: "A test project",
        visibility: "discoverable",
      },
    },
  };

  const MOCK_CREATE_RESPONSE = {
    data: {
      redirect_url: "/projects/123",
      summary: { components_imported: 2 },
      toast: "Project created from backup successfully.",
    },
  };

  const createWrapper = () => {
    return mount(RestoreProjectModal, {
      localVue,
      stubs: {
        "b-modal": {
          template: `
            <div v-if="value" class="modal">
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
    // Mock globalThis.location
    delete globalThis.location;
    globalThis.location = { href: "" };
  });

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("upload step", () => {
    it("renders file input", async () => {
      wrapper = createWrapper();
      wrapper.vm.showModal();
      await wrapper.vm.$nextTick();

      expect(wrapper.find('[data-testid="backup-file-input"]').exists()).toBe(true);
    });

    it("renders project name input", async () => {
      wrapper = createWrapper();
      wrapper.vm.showModal();
      await wrapper.vm.$nextTick();

      expect(wrapper.find('[data-testid="project-name-input"]').exists()).toBe(true);
    });

    it("renders project visibility select", async () => {
      wrapper = createWrapper();
      wrapper.vm.showModal();
      await wrapper.vm.$nextTick();

      expect(wrapper.find('[data-testid="project-visibility-select"]').exists()).toBe(true);
    });

    it("preview button disabled when no file selected", async () => {
      wrapper = createWrapper();
      wrapper.vm.showModal();
      await wrapper.vm.$nextTick();

      const btn = wrapper.find('[data-testid="preview-btn"]');
      expect(btn.attributes("disabled")).toBeDefined();
    });

    it("preview button disabled when no project name", async () => {
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });
      await wrapper.vm.$nextTick();

      const btn = wrapper.find('[data-testid="preview-btn"]');
      expect(btn.attributes("disabled")).toBeDefined();
    });

    it("preview button enabled when file and name provided", async () => {
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });
      wrapper.vm.projectName = "Test Project";
      await wrapper.vm.$nextTick();

      const btn = wrapper.find('[data-testid="preview-btn"]');
      expect(btn.attributes("disabled")).toBeUndefined();
    });
  });

  describe("dry run (preview)", () => {
    it("pre-fills name from archive defaults", async () => {
      axios.post.mockResolvedValue(MOCK_DRY_RUN_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });

      await wrapper.vm.submitDryRun();

      expect(wrapper.vm.projectName).toBe("My Original Project");
    });

    it("does not overwrite user-entered name", async () => {
      axios.post.mockResolvedValue(MOCK_DRY_RUN_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });
      wrapper.vm.projectName = "Custom Name";

      await wrapper.vm.submitDryRun();

      expect(wrapper.vm.projectName).toBe("Custom Name");
    });

    it("moves to preview step on success", async () => {
      axios.post.mockResolvedValue(MOCK_DRY_RUN_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });

      await wrapper.vm.submitDryRun();

      expect(wrapper.vm.step).toBe("preview");
    });

    it("shows summary in preview", async () => {
      axios.post.mockResolvedValue(MOCK_DRY_RUN_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });

      await wrapper.vm.submitDryRun();
      await wrapper.vm.$nextTick();

      expect(wrapper.text()).toContain("94");
    });

    it("shows component names and rule counts in preview", async () => {
      axios.post.mockResolvedValue(MOCK_DRY_RUN_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });

      await wrapper.vm.submitDryRun();
      await wrapper.vm.$nextTick();

      const list = wrapper.find('[data-testid="component-list"]');
      expect(list.exists()).toBe(true);
      const rows = wrapper.findAll('[data-testid="component-detail-row"]');
      expect(rows.length).toBe(2);
      expect(wrapper.text()).toContain("Photon OS 4");
      expect(wrapper.text()).toContain("RHEL 9");
      expect(wrapper.text()).toContain("50 rules");
      expect(wrapper.text()).toContain("44 rules");
    });

    it("calls correct endpoint", async () => {
      axios.post.mockResolvedValue(MOCK_DRY_RUN_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });

      await wrapper.vm.submitDryRun();

      expect(axios.post).toHaveBeenCalledWith(
        "/projects/create_from_backup",
        expect.any(FormData),
        expect.objectContaining({
          headers: { "Content-Type": "multipart/form-data" },
        }),
      );
    });
  });

  describe("create (confirm)", () => {
    it("sends correct params", async () => {
      axios.post.mockResolvedValue(MOCK_CREATE_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });
      wrapper.vm.projectName = "My Project";
      wrapper.vm.projectDescription = "Description";
      wrapper.vm.projectVisibility = "hidden";
      wrapper.vm.step = "preview";

      await wrapper.vm.submitCreate();

      const formData = axios.post.mock.calls[0][1];
      expect(formData.get("project_name")).toBe("My Project");
      expect(formData.get("project_description")).toBe("Description");
      expect(formData.get("project_visibility")).toBe("hidden");
    });

    it("redirects on success", async () => {
      axios.post.mockResolvedValue(MOCK_CREATE_RESPONSE);
      wrapper = createWrapper();
      wrapper.vm.showModal();
      wrapper.vm.file = new File(["test"], "backup.zip", { type: "application/zip" });
      wrapper.vm.projectName = "My Project";
      wrapper.vm.step = "preview";

      await wrapper.vm.submitCreate();

      expect(globalThis.location).toBe("/projects/123");
    });
  });

  describe("navigation", () => {
    it("back button returns to upload", async () => {
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
      wrapper.vm.projectName = "Test";
      wrapper.vm.step = "preview";

      wrapper.vm.modalShow = false;
      wrapper.vm.showModal();

      expect(wrapper.vm.step).toBe("upload");
      expect(wrapper.vm.projectName).toBe("");
      expect(wrapper.vm.file).toBe(null);
    });
  });
});
