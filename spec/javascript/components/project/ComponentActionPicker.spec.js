import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ComponentActionPicker from "@/components/project/ComponentActionPicker.vue";

/**
 * ComponentActionPicker - Modal for selecting component creation method
 *
 * REQUIREMENTS:
 *
 * 1. SHOWS 4 OPTIONS (Radio buttons):
 *    - Create New Component (Start from scratch)
 *    - Import From Spreadsheet (Upload XLSX/CSV)
 *    - Copy Existing Component (Duplicate from project)
 *    - Add Overlaid Component (Import released STIG)
 *
 * 2. EACH OPTION HAS:
 *    - Icon
 *    - Title
 *    - Description
 *
 * 3. NEXT BUTTON:
 *    - Disabled until option selected
 *    - Emits selected option type
 *
 * 4. CANCEL:
 *    - Closes modal
 *    - Emits cancel event
 *
 * 5. V-MODEL:
 *    - Controls visibility
 *    - Emits update:visible
 */
describe("ComponentActionPicker", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return mount(ComponentActionPicker, {
      localVue,
      propsData: {
        visible: true,
        ...props,
      },
      stubs: {
        "b-modal": {
          template: `
            <div class="modal" :class="{ 'd-block': visible, 'd-none': !visible }">
              <div class="modal-title">{{ title }}</div>
              <slot></slot>
              <slot name="modal-footer"></slot>
            </div>
          `,
          props: ["visible", "title", "centered"],
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
  // OPTION RENDERING
  // ==========================================
  describe("option rendering", () => {
    it("shows all 4 component action options", () => {
      wrapper = createWrapper();
      const radios = wrapper.findAll('input[type="radio"]');
      expect(radios.length).toBe(4);
    });

    it("shows Create New option with description", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Create New Component");
      expect(wrapper.text()).toContain("Start from scratch");
    });

    it("shows Import Spreadsheet option with description", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Import From Spreadsheet");
      expect(wrapper.text()).toContain("Upload XLSX");
    });

    it("shows Copy Existing option with description", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Copy Existing Component");
      expect(wrapper.text()).toContain("Duplicate from this project");
    });

    it("shows Add Overlay option with description", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Add Overlaid Component");
      expect(wrapper.text()).toContain("Import released STIG");
    });

    it("has no option selected by default", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.selectedAction).toBe(null);
    });
  });

  // ==========================================
  // SELECTION BEHAVIOR
  // ==========================================
  describe("selection behavior", () => {
    it("updates selectedAction when option clicked", async () => {
      wrapper = createWrapper();
      const createRadio = wrapper.find('input[value="create"]');
      await createRadio.setChecked();
      expect(wrapper.vm.selectedAction).toBe("create");
    });

    it("can select import option", async () => {
      wrapper = createWrapper();
      const importRadio = wrapper.find('input[value="import"]');
      await importRadio.setChecked();
      expect(wrapper.vm.selectedAction).toBe("import");
    });

    it("can select copy option", async () => {
      wrapper = createWrapper();
      const copyRadio = wrapper.find('input[value="copy"]');
      await copyRadio.setChecked();
      expect(wrapper.vm.selectedAction).toBe("copy");
    });

    it("can select overlay option", async () => {
      wrapper = createWrapper();
      const overlayRadio = wrapper.find('input[value="overlay"]');
      await overlayRadio.setChecked();
      expect(wrapper.vm.selectedAction).toBe("overlay");
    });
  });

  // ==========================================
  // NEXT BUTTON
  // ==========================================
  describe("next button", () => {
    it("is disabled when no option selected", () => {
      wrapper = createWrapper();
      const nextBtn = wrapper.find('[data-testid="next-btn"]');
      expect(nextBtn.attributes("disabled")).toBeDefined();
    });

    it("is enabled when option selected", async () => {
      wrapper = createWrapper();
      wrapper.vm.selectedAction = "create";
      await wrapper.vm.$nextTick();
      const nextBtn = wrapper.find('[data-testid="next-btn"]');
      expect(nextBtn.attributes("disabled")).toBeUndefined();
    });

    it("emits next event with selected action type", async () => {
      wrapper = createWrapper();
      wrapper.vm.selectedAction = "import";
      await wrapper.vm.$nextTick();

      const nextBtn = wrapper.find('[data-testid="next-btn"]');
      await nextBtn.trigger("click");

      expect(wrapper.emitted("next")).toBeTruthy();
      expect(wrapper.emitted("next")[0]).toEqual(["import"]);
    });

    it("closes modal after emitting next", async () => {
      wrapper = createWrapper();
      wrapper.vm.selectedAction = "create";
      await wrapper.vm.$nextTick();

      const nextBtn = wrapper.find('[data-testid="next-btn"]');
      await nextBtn.trigger("click");

      expect(wrapper.emitted("update:visible")).toBeTruthy();
      expect(wrapper.emitted("update:visible")[0]).toEqual([false]);
    });
  });

  // ==========================================
  // CANCEL BUTTON
  // ==========================================
  describe("cancel button", () => {
    it("emits cancel event", async () => {
      wrapper = createWrapper();
      const cancelBtn = wrapper.find('[data-testid="cancel-btn"]');
      await cancelBtn.trigger("click");
      expect(wrapper.emitted("cancel")).toBeTruthy();
    });

    it("closes modal", async () => {
      wrapper = createWrapper();
      const cancelBtn = wrapper.find('[data-testid="cancel-btn"]');
      await cancelBtn.trigger("click");
      expect(wrapper.emitted("update:visible")[0]).toEqual([false]);
    });
  });

  // ==========================================
  // MODAL BEHAVIOR
  // ==========================================
  describe("modal behavior", () => {
    it("resets selection when modal opens", async () => {
      wrapper = createWrapper({ visible: false });
      wrapper.vm.selectedAction = "create";
      await wrapper.setProps({ visible: true });
      expect(wrapper.vm.selectedAction).toBe(null);
    });

    it("shows modal title", () => {
      wrapper = createWrapper();
      expect(wrapper.find(".modal-title").text()).toBe("Add Component");
    });
  });
});
