import { describe, it, expect } from "vitest";
import { useDisplayedComponent } from "../../../app/javascript/composables/useDisplayedComponent";

describe("useDisplayedComponent", () => {
  const { addDisplayNameToComponents } = useDisplayedComponent();

  it("adds displayed name with version and release", () => {
    const components = [{ name: "Test", version: "1", release: "R1" }];
    const result = addDisplayNameToComponents(components);
    expect(result[0].displayed).toBe("Test (Version 1, Release R1)");
  });

  it("adds displayed name with version only — no comma artifact", () => {
    const components = [{ name: "Test", version: "2", release: "" }];
    const result = addDisplayNameToComponents(components);
    expect(result[0].displayed).toBe("Test (Version 2)");
  });

  it("adds displayed name with release only — no comma artifact", () => {
    const components = [{ name: "Test", version: "", release: "R3" }];
    const result = addDisplayNameToComponents(components);
    expect(result[0].displayed).toBe("Test (Release R3)");
  });

  it("uses the bare name when neither version nor release — no trailing space", () => {
    const components = [{ name: "Test", version: "", release: "" }];
    const result = addDisplayNameToComponents(components);
    expect(result[0].displayed).toBe("Test");
  });

  it("handles multiple components", () => {
    const components = [
      { name: "A", version: "1", release: "R1" },
      { name: "B", version: "2", release: "R2" },
    ];
    const result = addDisplayNameToComponents(components);
    expect(result).toHaveLength(2);
    expect(result[0].displayed).toBe("A (Version 1, Release R1)");
    expect(result[1].displayed).toBe("B (Version 2, Release R2)");
  });

  it("returns empty array for empty input", () => {
    expect(addDisplayNameToComponents([])).toEqual([]);
  });
});
