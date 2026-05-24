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

  it("renders breadcrumb with STIGs for type=STIG", () => {
    const wrapper = mount(BenchmarkListPage, {
      propsData: { type: "STIG", givenItems: mockItems, isAdmin: false },
      stubs: ["BaseCommandBar", "BenchmarkTable", "BenchmarkUpload", "ExportModal", "b-breadcrumb", "b-badge"],
    });
    expect(wrapper.vm.pluralLabel).toBe("STIGs");
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

  it("derives apiPath from type", () => {
    const wrapper = mount(BenchmarkListPage, {
      propsData: { type: "SRG", givenItems: [], isAdmin: false },
      stubs: ["BaseCommandBar", "BenchmarkTable", "BenchmarkUpload", "ExportModal", "b-breadcrumb", "b-badge"],
    });
    expect(wrapper.vm.apiPath).toBe("/srgs");
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
});
