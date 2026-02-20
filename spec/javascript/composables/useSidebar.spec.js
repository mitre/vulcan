import { describe, it, expect } from "vitest";
import { useSidebar } from "@/composables/useSidebar";

describe("useSidebar", () => {
  describe("initialization", () => {
    it("initializes with no active panel", () => {
      const { activePanel } = useSidebar();
      expect(activePanel.value).toBeNull();
    });

    it("initializes with all sidebars closed", () => {
      const { isSidebarOpen } = useSidebar();
      expect(isSidebarOpen("related")).toBe(false);
      expect(isSidebarOpen("satisfies")).toBe(false);
      expect(isSidebarOpen("reviews")).toBe(false);
      expect(isSidebarOpen("history")).toBe(false);
    });
  });

  describe("togglePanel", () => {
    it("opens a panel when closed", () => {
      const { activePanel, togglePanel } = useSidebar();
      togglePanel("reviews");
      expect(activePanel.value).toBe("reviews");
    });

    it("closes a panel when already open", () => {
      const { activePanel, togglePanel } = useSidebar();
      togglePanel("reviews");
      togglePanel("reviews");
      expect(activePanel.value).toBeNull();
    });

    it("switches to new panel when different panel is open", () => {
      const { activePanel, togglePanel } = useSidebar();
      togglePanel("reviews");
      togglePanel("history");
      expect(activePanel.value).toBe("history");
    });
  });

  describe("openPanel", () => {
    it("opens a specific panel", () => {
      const { activePanel, openPanel } = useSidebar();
      openPanel("satisfies");
      expect(activePanel.value).toBe("satisfies");
    });

    it("switches panels when already open", () => {
      const { activePanel, openPanel } = useSidebar();
      openPanel("reviews");
      openPanel("history");
      expect(activePanel.value).toBe("history");
    });
  });

  describe("closePanel", () => {
    it("closes the active panel", () => {
      const { activePanel, openPanel, closePanel } = useSidebar();
      openPanel("reviews");
      closePanel();
      expect(activePanel.value).toBeNull();
    });

    it("does nothing when no panel is open", () => {
      const { activePanel, closePanel } = useSidebar();
      closePanel();
      expect(activePanel.value).toBeNull();
    });
  });

  describe("isSidebarOpen", () => {
    it("returns true for the active panel", () => {
      const { openPanel, isSidebarOpen } = useSidebar();
      openPanel("reviews");
      expect(isSidebarOpen("reviews")).toBe(true);
    });

    it("returns false for inactive panels", () => {
      const { openPanel, isSidebarOpen } = useSidebar();
      openPanel("reviews");
      expect(isSidebarOpen("history")).toBe(false);
      expect(isSidebarOpen("satisfies")).toBe(false);
    });
  });

  describe("isPanelActive", () => {
    it("returns true when specified panel is active", () => {
      const { openPanel, isPanelActive } = useSidebar();
      openPanel("history");
      expect(isPanelActive("history")).toBe(true);
    });

    it("returns false when different panel is active", () => {
      const { openPanel, isPanelActive } = useSidebar();
      openPanel("reviews");
      expect(isPanelActive("history")).toBe(false);
    });

    it("returns false when no panel is active", () => {
      const { isPanelActive } = useSidebar();
      expect(isPanelActive("reviews")).toBe(false);
    });
  });

  describe("body scroll lock", () => {
    it("locks body scroll when panel is opened", () => {
      const { openPanel } = useSidebar();
      openPanel("reviews");
      expect(document.body.style.overflow).toBe("hidden");
    });

    it("unlocks body scroll when panel is closed", () => {
      const { openPanel, closePanel } = useSidebar();
      openPanel("reviews");
      closePanel();
      expect(document.body.style.overflow).toBe("");
    });

    it("keeps body scroll locked when switching panels", () => {
      const { togglePanel } = useSidebar();
      togglePanel("reviews");
      expect(document.body.style.overflow).toBe("hidden");
      togglePanel("history");
      expect(document.body.style.overflow).toBe("hidden");
    });

    it("unlocks body scroll when toggling same panel off", () => {
      const { togglePanel } = useSidebar();
      togglePanel("reviews");
      togglePanel("reviews");
      expect(document.body.style.overflow).toBe("");
    });
  });

  describe("panelNames", () => {
    it("provides list of valid panel names", () => {
      const { panelNames } = useSidebar();
      expect(panelNames).toContain("related");
      expect(panelNames).toContain("satisfies");
      expect(panelNames).toContain("reviews");
      expect(panelNames).toContain("history");
    });
  });
});
