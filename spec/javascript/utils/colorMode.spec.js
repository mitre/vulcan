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
    // The store empties above, but the spies' CALL HISTORY is per-suite —
    // without this, a negative assertion (not.toHaveBeenCalledWith) reads
    // calls made by earlier examples.
    vi.clearAllMocks();
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

    // The in-app documentation pages decide their theme pre-paint from the
    // docs generator's own storage key. Mirroring the preference there is
    // what makes the served docs follow the app with no flash of the wrong
    // theme — the docs' inline init script reads only its own key.
    it("mirrors the preference to the documentation site's key", () => {
      colorMode.setStoredTheme("dark");
      expect(localStorage.setItem).toHaveBeenCalledWith("vitepress-theme-appearance", "dark");
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

    // A preference stored before the mirror existed has never been copied to
    // the docs key; init is the moment every page load passes through, so it
    // brings the docs key up to date for those readers.
    it("mirrors an existing stored preference to the documentation key", () => {
      localStorage.setItem("vulcan-theme", "dark");
      colorMode.initTheme();
      expect(localStorage.setItem).toHaveBeenCalledWith("vitepress-theme-appearance", "dark");
    });

    it("does not write the documentation key when nothing is stored", () => {
      colorMode.initTheme();
      expect(localStorage.setItem).not.toHaveBeenCalledWith(
        "vitepress-theme-appearance",
        expect.anything(),
      );
    });
  });
});
