import { bvConfig } from "@/config/bootstrapVueConfig";

describe("bootstrapVueConfig", () => {
  it("exports a config object with BButton size sm", () => {
    expect(bvConfig.BButton.size).toBe("sm");
  });

  it("exports a config object with BFormInput size sm", () => {
    expect(bvConfig.BFormInput.size).toBe("sm");
  });

  it("exports a config object with BFormSelect size sm", () => {
    expect(bvConfig.BFormSelect.size).toBe("sm");
  });

  it("exports a config object with BFormTextarea size sm", () => {
    expect(bvConfig.BFormTextarea.size).toBe("sm");
  });

  it("exports a config object with BDropdown size sm", () => {
    expect(bvConfig.BDropdown.size).toBe("sm");
  });

  it("exports a config object with BInputGroup size sm", () => {
    expect(bvConfig.BInputGroup.size).toBe("sm");
  });

  it("exports a config object with BPagination size sm", () => {
    expect(bvConfig.BPagination.size).toBe("sm");
  });
});
