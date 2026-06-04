import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useThemeStore } from "@/stores/theme";

vi.mock("@/utils/colorMode", () => ({
  getPreferredTheme: vi.fn(() => "light"),
  applyTheme: vi.fn(),
  setStoredTheme: vi.fn(),
}));

import { getPreferredTheme, applyTheme, setStoredTheme } from "@/utils/colorMode";

describe("useThemeStore", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    document.documentElement.setAttribute("data-bs-theme", "light");
    vi.clearAllMocks();
  });

  afterEach(() => {
    document.documentElement.removeAttribute("data-bs-theme");
  });

  it("initializes isDark from the DOM attribute", () => {
    document.documentElement.setAttribute("data-bs-theme", "dark");
    const store = useThemeStore();
    expect(store.isDark).toBe(true);
  });

  it("initializes isDark as false when theme is light", () => {
    const store = useThemeStore();
    expect(store.isDark).toBe(false);
  });

  it("toggle switches from light to dark", () => {
    const store = useThemeStore();
    store.toggle();
    expect(store.isDark).toBe(true);
    expect(applyTheme).toHaveBeenCalledWith("dark");
    expect(setStoredTheme).toHaveBeenCalledWith("dark");
  });

  it("toggle switches from dark to light", () => {
    document.documentElement.setAttribute("data-bs-theme", "dark");
    const store = useThemeStore();
    store.toggle();
    expect(store.isDark).toBe(false);
    expect(applyTheme).toHaveBeenCalledWith("light");
    expect(setStoredTheme).toHaveBeenCalledWith("light");
  });

  it("init applies the preferred theme", () => {
    getPreferredTheme.mockReturnValue("dark");
    const store = useThemeStore();
    store.init();
    expect(applyTheme).toHaveBeenCalledWith("dark");
  });
});
