/**
 * RevisionHistory Regression Tests
 *
 * REQUIREMENTS:
 *
 * 1. The component selector renders as FilterDropdown, not <b-form-select>.
 * 2. uniqueComponentNames is an array of strings; the dropdown maps to the
 *    `[{value, text}]` shape FilterDropdown's options validator requires.
 * 3. Selection invokes fetchRevisionHistory (preserve current behavior —
 *    @change on b-form-select moves to handler on emit("input")).
 */
import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RevisionHistory from "@/components/project/RevisionHistory.vue";

describe("RevisionHistory — Task 28 FilterDropdown migration", () => {
  const mountIt = (overrides = {}) =>
    mount(RevisionHistory, {
      localVue,
      propsData: {
        project: { id: 7, name: "Demo Project" },
        uniqueComponentNames: ["Comp A", "Comp B"],
        ...overrides,
      },
    });

  it("renders FilterDropdown for the component selector (not native <select>)", () => {
    const w = mountIt();
    expect(w.findComponent({ name: "FilterDropdown" }).exists()).toBe(true);
    expect(w.find("select").exists()).toBe(false);
  });

  it("maps uniqueComponentNames strings to FilterDropdown's {value, text} option shape", () => {
    const w = mountIt();
    const fd = w.findComponent({ name: "FilterDropdown" });
    expect(fd.props("options")).toEqual([
      { value: "Comp A", text: "Comp A" },
      { value: "Comp B", text: "Comp B" },
    ]);
  });

  it("selecting a component triggers fetchRevisionHistory (via emit on input)", async () => {
    const spy = vi.spyOn(RevisionHistory.methods, "fetchRevisionHistory");
    const w = mountIt();
    const fd = w.findComponent({ name: "FilterDropdown" });
    fd.vm.$emit("input", "Comp A");
    await w.vm.$nextTick();
    expect(w.vm.componentName).toBe("Comp A");
    expect(spy).toHaveBeenCalled();
    spy.mockRestore();
  });
});
