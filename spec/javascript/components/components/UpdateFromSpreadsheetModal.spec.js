import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import UpdateFromSpreadsheetModal from "@/components/components/UpdateFromSpreadsheetModal.vue";

/**
 * UpdateFromSpreadsheetModal Contract Tests
 *
 * REQUIREMENTS:
 * 1. Shows file input on open (Step 1)
 * 2. Preview button disabled until file selected
 * 3. Advances to preview after successful preview API call (Step 2)
 * 4. Tracks locked rules in preview data
 * 5. Shows error on API failure
 * 6. Progress spinner state during update (Step 4)
 * 7. Success result on completion (Step 5)
 * 8. Emits spreadsheet-updated on success close
 *
 * NOTE: b-modal renders body lazily in jsdom. Tests that verify modal body
 * DOM use attachTo: document.body. Tests for computed/state use vm directly.
 */

vi.mock("axios", () => ({
  default: {
    post: vi.fn(() => Promise.resolve({ data: {} })),
    patch: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } },
  },
}));

import axios from "axios";

describe("UpdateFromSpreadsheetModal", () => {
  let wrapper;

  const defaultProps = {
    component: { id: 42, name: "Test Component", prefix: "TEST-01" },
  };

  const mockPreviewResponse = {
    data: {
      updated: [
        {
          rule_id: "001",
          srg_id: "SRG-OS-000001",
          changes: { title: { from: "Old Title", to: "New Title" } },
        },
        {
          rule_id: "002",
          srg_id: "SRG-OS-000002",
          changes: { fixtext: { from: "Old Fix", to: "New Fix" } },
        },
      ],
      unchanged: [{ rule_id: "003", srg_id: "SRG-OS-000003" }],
      skipped_locked: [{ rule_id: "004", srg_id: "SRG-OS-000004" }],
      warnings: ["Column 'extra_col' was ignored"],
    },
  };

  const createWrapper = (props = {}) => {
    const div = document.createElement("div");
    document.body.appendChild(div);
    return mount(UpdateFromSpreadsheetModal, {
      localVue,
      attachTo: div,
      propsData: { ...defaultProps, ...props },
    });
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
      wrapper = null;
    }
  });

  describe("Step 1: File Select", () => {
    it("renders the opener button", () => {
      wrapper = createWrapper();
      expect(wrapper.find('[data-testid="update-from-spreadsheet-btn"]').exists()).toBe(true);
      expect(wrapper.find('[data-testid="update-from-spreadsheet-btn"]').text()).toContain(
        "Update from Spreadsheet",
      );
    });

    it("has Preview button disabled when no file selected (computed)", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.modalOkDisabled).toBe(true);
    });

    it("enables Preview button when file is selected (computed)", async () => {
      wrapper = createWrapper();
      wrapper.vm.selectedFile = new File(["content"], "test.csv", { type: "text/csv" });
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.modalOkDisabled).toBe(false);
    });
  });

  describe("Step 2: Preview (state verification)", () => {
    it("advances to step 2 after successful preview API call", async () => {
      axios.post.mockResolvedValueOnce(mockPreviewResponse);
      wrapper = createWrapper();

      wrapper.vm.selectedFile = new File(["content"], "test.csv");
      await wrapper.vm.fetchPreview();

      expect(wrapper.vm.step).toBe(2);
      expect(wrapper.vm.previewData.updated).toHaveLength(2);
      expect(wrapper.vm.previewData.unchanged).toHaveLength(1);
      expect(wrapper.vm.previewData.skipped_locked).toHaveLength(1);
      expect(wrapper.vm.previewData.warnings).toHaveLength(1);
    });

    it("sets correct modal title for preview step", async () => {
      axios.post.mockResolvedValueOnce(mockPreviewResponse);
      wrapper = createWrapper();

      wrapper.vm.selectedFile = new File(["content"], "test.csv");
      await wrapper.vm.fetchPreview();

      expect(wrapper.vm.modalTitle).toContain("2 rules to update");
    });

    it("sets modal size to xl for preview step", async () => {
      axios.post.mockResolvedValueOnce(mockPreviewResponse);
      wrapper = createWrapper();

      wrapper.vm.selectedFile = new File(["content"], "test.csv");
      await wrapper.vm.fetchPreview();

      expect(wrapper.vm.modalSize).toBe("xl");
    });

    it("builds table items from preview data", async () => {
      axios.post.mockResolvedValueOnce(mockPreviewResponse);
      wrapper = createWrapper();

      wrapper.vm.selectedFile = new File(["content"], "test.csv");
      await wrapper.vm.fetchPreview();

      expect(wrapper.vm.updatedTableItems).toHaveLength(2);
      expect(wrapper.vm.updatedTableItems[0].rule_id).toBe("001");
      expect(wrapper.vm.updatedTableItems[0].changes).toHaveProperty("title");
    });
  });

  describe("Error handling", () => {
    it("stays on step 1 and sets fileError on preview API failure", async () => {
      axios.post.mockRejectedValueOnce({
        response: { data: { error: "Missing required header: SRGID" } },
      });
      wrapper = createWrapper();

      wrapper.vm.selectedFile = new File(["content"], "test.csv");
      await wrapper.vm.fetchPreview();

      expect(wrapper.vm.step).toBe(1);
      expect(wrapper.vm.fileError).toBe("Missing required header: SRGID");
    });

    it("sets generic error when API response has no error field", async () => {
      axios.post.mockRejectedValueOnce({ response: { data: {} } });
      wrapper = createWrapper();

      wrapper.vm.selectedFile = new File(["content"], "test.csv");
      await wrapper.vm.fetchPreview();

      expect(wrapper.vm.fileError).toBe("Failed to preview spreadsheet");
    });

    it("sets error result on apply failure", async () => {
      axios.patch.mockRejectedValueOnce({
        response: { data: { error: "Could not save rules" } },
      });
      wrapper = createWrapper();

      wrapper.vm.selectedFile = new File(["content"], "test.csv");
      wrapper.vm.previewData = mockPreviewResponse.data;

      await wrapper.vm.applyChanges();

      expect(wrapper.vm.step).toBe(5);
      expect(wrapper.vm.updateResult.success).toBe(false);
      expect(wrapper.vm.updateResult.message).toBe("Could not save rules");
    });
  });

  describe("Step 4: Progress", () => {
    it("sets step to 4 during update", async () => {
      let resolveApply;
      axios.patch.mockReturnValueOnce(
        new Promise((resolve) => {
          resolveApply = resolve;
        }),
      );

      wrapper = createWrapper();
      wrapper.vm.selectedFile = new File(["content"], "test.csv");
      wrapper.vm.previewData = mockPreviewResponse.data;

      const applyPromise = wrapper.vm.applyChanges();

      // Step should be 4 immediately (synchronous assignment before async)
      expect(wrapper.vm.step).toBe(4);
      expect(wrapper.vm.modalTitle).toBe("Updating rules...");
      expect(wrapper.vm.modalOkDisabled).toBe(true);

      resolveApply({ data: { toast: "Done" } });
      await applyPromise;
    });
  });

  describe("Step 5: Results", () => {
    it("sets success result on completion", async () => {
      axios.patch.mockResolvedValueOnce({
        data: { toast: "Successfully updated 2 rules from spreadsheet." },
      });
      wrapper = createWrapper();

      wrapper.vm.selectedFile = new File(["content"], "test.csv");
      wrapper.vm.previewData = mockPreviewResponse.data;

      await wrapper.vm.applyChanges();

      expect(wrapper.vm.step).toBe(5);
      expect(wrapper.vm.updateResult.success).toBe(true);
      expect(wrapper.vm.updateResult.message).toBe(
        "Successfully updated 2 rules from spreadsheet.",
      );
      expect(wrapper.vm.modalTitle).toBe("Update Complete");
    });

    it("emits spreadsheet-updated on success close", () => {
      wrapper = createWrapper();
      wrapper.vm.updateResult = { success: true, message: "Done" };
      wrapper.vm.step = 5;

      wrapper.vm.onResultsClose();

      expect(wrapper.emitted("spreadsheet-updated")).toBeTruthy();
    });

    it("does not emit spreadsheet-updated on error close", () => {
      wrapper = createWrapper();
      wrapper.vm.updateResult = { success: false, message: "Failed" };
      wrapper.vm.step = 5;

      wrapper.vm.onResultsClose();

      expect(wrapper.emitted("spreadsheet-updated")).toBeFalsy();
    });
  });

  describe("Modal navigation", () => {
    it("resets state on modal hidden", () => {
      wrapper = createWrapper();
      wrapper.vm.step = 3;
      wrapper.vm.fileError = "some error";
      wrapper.vm.selectedFile = new File(["x"], "x.csv");

      wrapper.vm.onHidden();

      expect(wrapper.vm.step).toBe(1);
      expect(wrapper.vm.fileError).toBeNull();
      expect(wrapper.vm.selectedFile).toBeNull();
      expect(wrapper.vm.previewData.updated).toHaveLength(0);
    });

    it("does not fetch preview without a file", async () => {
      wrapper = createWrapper();
      wrapper.vm.selectedFile = null;

      wrapper.vm.fetchPreview();

      expect(wrapper.vm.fileError).toBe("Please select a file");
      expect(axios.post).not.toHaveBeenCalled();
    });

    it("calls correct API endpoint for preview", async () => {
      axios.post.mockResolvedValueOnce(mockPreviewResponse);
      wrapper = createWrapper();

      wrapper.vm.selectedFile = new File(["content"], "test.csv");
      await wrapper.vm.fetchPreview();

      expect(axios.post).toHaveBeenCalledWith(
        "/components/42/preview_spreadsheet_update",
        expect.any(FormData),
        expect.objectContaining({
          headers: { "Content-Type": "multipart/form-data" },
        }),
      );
    });

    it("calls correct API endpoint for apply", async () => {
      axios.patch.mockResolvedValueOnce({ data: { toast: "Done" } });
      wrapper = createWrapper();

      wrapper.vm.selectedFile = new File(["content"], "test.csv");
      wrapper.vm.previewData = mockPreviewResponse.data;

      await wrapper.vm.applyChanges();

      expect(axios.patch).toHaveBeenCalledWith(
        "/components/42/apply_spreadsheet_update",
        expect.any(FormData),
        expect.objectContaining({
          headers: { "Content-Type": "multipart/form-data" },
        }),
      );
    });
  });

  describe("Computed properties", () => {
    it("returns correct ok title per step", () => {
      wrapper = createWrapper();

      wrapper.vm.step = 1;
      expect(wrapper.vm.modalOkTitle).toBe("Preview");

      // Step 2 with updates shows "Apply Changes"
      wrapper.vm.previewData = {
        updated: [{ rule_id: "R1", changes: {} }],
        unchanged: [],
        skipped_locked: [],
        warnings: [],
      };
      wrapper.vm.step = 2;
      expect(wrapper.vm.modalOkTitle).toBe("Apply Changes");

      wrapper.vm.step = 3;
      expect(wrapper.vm.modalOkTitle).toBe("Yes, Update");

      wrapper.vm.step = 5;
      expect(wrapper.vm.modalOkTitle).toBe("Close");
    });

    it("returns Done ok title at step 2 when no updates", () => {
      wrapper = createWrapper();
      wrapper.vm.step = 2;
      expect(wrapper.vm.modalOkTitle).toBe("Done");
    });

    it("returns correct cancel title per step", () => {
      wrapper = createWrapper();

      wrapper.vm.step = 1;
      expect(wrapper.vm.modalCancelTitle).toBe("Cancel");

      wrapper.vm.step = 2;
      expect(wrapper.vm.modalCancelTitle).toBe("Back");

      wrapper.vm.step = 3;
      expect(wrapper.vm.modalCancelTitle).toBe("Back");
    });

    it("shows Loading... ok title when updateInProgress", () => {
      wrapper = createWrapper();
      wrapper.vm.step = 1;
      wrapper.vm.updateInProgress = true;
      expect(wrapper.vm.modalOkTitle).toBe("Loading...");
    });

    it("truncates long strings", () => {
      wrapper = createWrapper();
      const short = "hello";
      const long = "a".repeat(100);

      expect(wrapper.vm.truncate(short)).toBe("hello");
      expect(wrapper.vm.truncate(long).length).toBe(80);
      expect(wrapper.vm.truncate(long)).toContain("...");
      expect(wrapper.vm.truncate(null)).toBe("");
    });
  });
});
