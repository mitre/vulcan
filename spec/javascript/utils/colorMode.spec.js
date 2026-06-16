import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

// Mock localStorage
const localStorageMock = (() => {
  let store = {};
  return {
    getItem: vi.fn((key) => store[key] || null),
    setItem: vi.fn((key, value) => {
      store[key] = String(value);
    }),
    removeItem: vi.fn((key) => {
      delete store[key];
    }),
    clear: () => {
      store = {};
    },
  };
})();

Object.defineProperty(globalThis, "localStorage", { value: localStorageMock });

describe("colorMode", () => {
  let colorMode;

  beforeEach(async () => {
    localStorageMock.clear();
    vi.resetModules();
    colorMode = await import("@/utils/colorMode");
  });

  afterEach(() => {
    document.documentElement.removeAttribute("data-bs-theme");
  });

  describe("getStoredTheme", () => {
    it("returns null when no theme stored", () => {
      expect(colorMode.getStoredTheme()).toBeNull();
    });

    it("returns stored theme from localStorage", () => {
      localStorage.setItem("vulcan-theme", "dark");
      expect(colorMode.getStoredTheme()).toBe("dark");
    });
  });

  describe("setStoredTheme", () => {
    it("persists theme to localStorage", () => {
      colorMode.setStoredTheme("dark");
      expect(localStorage.setItem).toHaveBeenCalledWith("vulcan-theme", "dark");
    });
  });

  describe("applyTheme", () => {
    it("sets data-bs-theme attribute on document element", () => {
      colorMode.applyTheme("dark");
      expect(document.documentElement.getAttribute("data-bs-theme")).toBe("dark");
    });

    it("sets light theme", () => {
      colorMode.applyTheme("light");
      expect(document.documentElement.getAttribute("data-bs-theme")).toBe("light");
    });
  });

  describe("toggleTheme", () => {
    it("switches from light to dark", () => {
      colorMode.applyTheme("light");
      const result = colorMode.toggleTheme();
      expect(result).toBe("dark");
      expect(document.documentElement.getAttribute("data-bs-theme")).toBe("dark");
    });

    it("switches from dark to light", () => {
      colorMode.applyTheme("dark");
      const result = colorMode.toggleTheme();
      expect(result).toBe("light");
      expect(document.documentElement.getAttribute("data-bs-theme")).toBe("light");
    });

    it("persists the new theme", () => {
      colorMode.applyTheme("light");
      colorMode.toggleTheme();
      expect(localStorage.setItem).toHaveBeenCalledWith("vulcan-theme", "dark");
    });
  });

  describe("initTheme", () => {
    it("applies stored theme when available", () => {
      localStorage.setItem("vulcan-theme", "dark");
      colorMode.initTheme();
      expect(document.documentElement.getAttribute("data-bs-theme")).toBe("dark");
    });

    it("defaults to light when no preference", () => {
      colorMode.initTheme();
      expect(document.documentElement.getAttribute("data-bs-theme")).toBe("light");
    });
  });
});
