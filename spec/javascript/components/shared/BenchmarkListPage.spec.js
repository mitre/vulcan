import { mount } from "@vue/test-utils";
import BenchmarkListPage from "../../../../app/javascript/components/shared/BenchmarkListPage.vue";

const mockItems = [
  { id: 1, title: "Test SRG", version: 2, release: 4, severity_counts: { high: 5, medium: 10, low: 2 } },
  { id: 2, title: "Another SRG", version: 3, release: 0, severity_counts: { high: 1, medium: 50, low: 0 } },
];

describe("BenchmarkListPage", () => {
  it("renders breadcrumb with SRGs for type=SRG", () => {
    const wrapper = mount(BenchmarkListPage, {
      propsData: { type: "SRG", givenItems: mockItems, isAdmin: false },
      stubs: ["BaseCommandBar", "BenchmarkTable", "BenchmarkUpload", "ExportModal", "b-breadcrumb", "b-badge"],
    });
    expect(wrapper.find("b-breadcrumb-stub").exists()).toBe(true);
  });

  it("renders STIG Count label for type=STIG", () => {
    const wrapper = mount(BenchmarkListPage, {
      propsData: { type: "STIG", givenItems: mockItems, isAdmin: false },
      stubs: ["BaseCommandBar", "BenchmarkTable", "BenchmarkUpload", "ExportModal", "b-breadcrumb", "b-badge"],
    });
    expect(wrapper.text()).toContain("STIG Count:");
  });

  it("shows upload button only for admins", () => {
    const wrapper = mount(BenchmarkListPage, {
      propsData: { type: "SRG", givenItems: mockItems, isAdmin: false },
      stubs: ["BaseCommandBar", "BenchmarkTable", "BenchmarkUpload", "ExportModal", "b-breadcrumb", "b-badge", "b-button", "b-icon"],
    });
    const uploadBtn = wrapper.find('[data-testid="upload-btn"]');
    expect(uploadBtn.exists()).toBe(false);
  });

  it("shows upload button for admins", () => {
    const wrapper = mount(BenchmarkListPage, {
      propsData: { type: "STIG", givenItems: mockItems, isAdmin: true },
      stubs: ["BaseCommandBar", "BenchmarkTable", "BenchmarkUpload", "ExportModal", "b-breadcrumb", "b-badge", "b-button", "b-icon"],
    });
    const uploadBtn = wrapper.find('[data-testid="upload-btn"]');
    expect(uploadBtn.exists()).toBe(true);
  });

  it("passes correct type to BenchmarkTable", () => {
    const wrapper = mount(BenchmarkListPage, {
      propsData: { type: "STIG", givenItems: mockItems, isAdmin: false },
      stubs: ["BaseCommandBar", "BenchmarkUpload", "ExportModal", "b-breadcrumb", "b-badge", "b-button", "b-icon", "BenchmarkTable"],
    });
    const table = wrapper.findComponent({ name: "BenchmarkTable" });
    expect(table.exists()).toBe(true);
    expect(table.props("type")).toBe("STIG");
  });

  it("renders SRG Count label for type=SRG", () => {
    const wrapper = mount(BenchmarkListPage, {
      propsData: { type: "SRG", givenItems: mockItems, isAdmin: false },
      stubs: ["BaseCommandBar", "BenchmarkTable", "BenchmarkUpload", "ExportModal", "b-breadcrumb", "b-badge"],
    });
    expect(wrapper.text()).toContain("SRG Count:");
  });

  it("derives apiPath for STIG type", () => {
    const wrapper = mount(BenchmarkListPage, {
      propsData: { type: "STIG", givenItems: [], isAdmin: false },
      stubs: ["BaseCommandBar", "BenchmarkTable", "BenchmarkUpload", "ExportModal", "b-breadcrumb", "b-badge"],
    });
    expect(wrapper.vm.apiPath).toBe("/stigs");
  });

  it("displays item count", () => {
    const wrapper = mount(BenchmarkListPage, {
      propsData: { type: "SRG", givenItems: mockItems, isAdmin: false },
      stubs: ["BaseCommandBar", "BenchmarkTable", "BenchmarkUpload", "ExportModal", "b-breadcrumb", "b-badge"],
    });
    expect(wrapper.text()).toContain("SRG Count:");
  });

  // Component type tests
  it("derives apiPath for Component type", () => {
    const wrapper = mount(BenchmarkListPage, {
      propsData: { type: "Component", givenItems: [], isAdmin: false },
      stubs: ["BaseCommandBar", "BenchmarkTable", "BenchmarkUpload", "ExportModal", "b-breadcrumb", "b-badge"],
    });
    expect(wrapper.vm.apiPath).toBe("/components");
    expect(wrapper.vm.pluralLabel).toBe("Released Components");
  });

  it("hides upload button for Component type even when admin", () => {
    const wrapper = mount(BenchmarkListPage, {
      propsData: { type: "Component", givenItems: mockItems, isAdmin: true },
      stubs: ["BaseCommandBar", "BenchmarkTable", "BenchmarkUpload", "ExportModal", "b-breadcrumb", "b-badge", "b-button", "b-icon"],
    });
    const uploadBtn = wrapper.find('[data-testid="upload-btn"]');
    expect(uploadBtn.exists()).toBe(false);
  });

  it("does not render BenchmarkUpload for Component type", () => {
    const wrapper = mount(BenchmarkListPage, {
      propsData: { type: "Component", givenItems: mockItems, isAdmin: true },
      stubs: ["BaseCommandBar", "BenchmarkTable", "ExportModal", "b-breadcrumb", "b-badge", "b-button", "b-icon", "BenchmarkUpload"],
    });
    expect(wrapper.findComponent({ name: "BenchmarkUpload" }).exists()).toBe(false);
  });

  it("config.bulkExport is true for Component type", () => {
    const wrapper = mount(BenchmarkListPage, {
      propsData: { type: "Component", givenItems: [], isAdmin: false },
      stubs: ["BaseCommandBar", "BenchmarkTable", "BenchmarkUpload", "ExportModal", "b-breadcrumb", "b-badge"],
    });
    expect(wrapper.vm.config.bulkExport).toBe(true);
  });
});
