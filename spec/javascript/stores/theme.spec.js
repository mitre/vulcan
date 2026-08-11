import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useThemeStore } from "@/stores/theme";

vi.mock("@/utils/colorMode", () => ({
  getPreferredTheme: vi.fn(() => "light"),
  applyTheme: vi.fn(),
  setStoredTheme: vi.fn(),
  initTheme: vi.fn(),
}));

import { applyTheme, setStoredTheme, initTheme } from "@/utils/colorMode";

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

  // The wiring is the requirement: initTheme applies the preference AND
  // mirrors a stored choice to the docs site's pre-paint key, and the navbar
  // boots through THIS init — a store that re-inlines the apply logic leaves
  // the mirror as dead code (which is exactly how it shipped broken once).
  it("init boots the theme through initTheme", () => {
    const store = useThemeStore();
    store.init();
    expect(initTheme).toHaveBeenCalledTimes(1);
  });
});
