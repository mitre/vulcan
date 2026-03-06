/**
 * useRuleAutosave — Autosave composable tests
 *
 * REQUIREMENTS:
 * 1. Debounced save — saves after 5s of inactivity, not on every keystroke
 * 2. Toggle — can be enabled/disabled, persists to localStorage
 * 3. Batched audit — uses "Auto-saved" comment, not user-provided
 * 4. Does not save when disabled
 * 5. Does not save when rule is locked or under review
 * 6. Tracks dirty state — knows if rule has unsaved changes
 * 7. Manual save resets the autosave timer
 */
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { ref } from "vue";
import { useRuleAutosave } from "@/composables/useRuleAutosave";
import axios from "axios";

vi.mock("axios", () => ({
  default: {
    put: vi.fn(() => Promise.resolve({ data: { toast: "saved" } })),
    defaults: { headers: { common: {} } },
  },
}));

describe("useRuleAutosave", () => {
  let rule;
  let autosave;

  beforeEach(() => {
    vi.useFakeTimers();
    vi.clearAllMocks();
    localStorage.clear();
    rule = ref({
      id: 1,
      title: "Original title",
      status: "Applicable - Configurable",
      locked: false,
      review_requestor_id: null,
    });
    autosave = useRuleAutosave(rule, { componentId: 42 });
  });

  afterEach(() => {
    autosave.destroy();
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  describe("toggle", () => {
    it("starts disabled by default", () => {
      expect(autosave.enabled.value).toBe(false);
    });

    it("can be toggled on", () => {
      autosave.toggle();
      expect(autosave.enabled.value).toBe(true);
    });

    it("persists toggle state to localStorage", () => {
      autosave.toggle();
      expect(localStorage.getItem("autosave-42")).toBe("true");
      autosave.toggle();
      expect(localStorage.getItem("autosave-42")).toBe("false");
    });

    it("reads initial state from localStorage", () => {
      localStorage.setItem("autosave-42", "true");
      const a2 = useRuleAutosave(rule, { componentId: 42 });
      expect(a2.enabled.value).toBe(true);
      a2.destroy();
    });
  });

  describe("dirty tracking", () => {
    it("starts clean", () => {
      expect(autosave.isDirty.value).toBe(false);
    });

    it("becomes dirty when markDirty is called", () => {
      autosave.markDirty();
      expect(autosave.isDirty.value).toBe(true);
    });

    it("becomes clean after save", async () => {
      autosave.toggle(); // enable
      autosave.markDirty();
      expect(autosave.isDirty.value).toBe(true);

      // Advance past debounce
      vi.advanceTimersByTime(6000);
      await vi.runAllTimersAsync();

      expect(autosave.isDirty.value).toBe(false);
    });
  });

  describe("debounced save", () => {
    it("does NOT save immediately when dirty", () => {
      autosave.toggle(); // enable
      autosave.markDirty();
      expect(axios.put).not.toHaveBeenCalled();
    });

    it("saves after debounce delay when enabled and dirty", async () => {
      autosave.toggle(); // enable
      autosave.markDirty();

      vi.advanceTimersByTime(6000);
      await vi.runAllTimersAsync();

      expect(axios.put).toHaveBeenCalledWith(
        "/rules/1",
        expect.objectContaining({
          rule: expect.objectContaining({
            audit_comment: "[Auto-saved]",
          }),
        }),
      );
    });

    it("does NOT save when disabled even if dirty", async () => {
      // Don't toggle — stays disabled
      autosave.markDirty();

      vi.advanceTimersByTime(6000);
      await vi.runAllTimersAsync();

      expect(axios.put).not.toHaveBeenCalled();
    });

    it("does NOT save when rule is locked", async () => {
      autosave.toggle();
      rule.value.locked = true;
      autosave.markDirty();

      vi.advanceTimersByTime(6000);
      await vi.runAllTimersAsync();

      expect(axios.put).not.toHaveBeenCalled();
    });

    it("does NOT save when rule is under review", async () => {
      autosave.toggle();
      rule.value.review_requestor_id = 42;
      autosave.markDirty();

      vi.advanceTimersByTime(6000);
      await vi.runAllTimersAsync();

      expect(axios.put).not.toHaveBeenCalled();
    });
  });

  describe("manual save reset", () => {
    it("resetTimer cancels pending autosave", async () => {
      autosave.toggle();
      autosave.markDirty();

      // Wait 3s (before debounce fires)
      vi.advanceTimersByTime(3000);
      autosave.resetTimer(); // manual save happened

      // Advance past original debounce
      vi.advanceTimersByTime(4000);
      await vi.runAllTimersAsync();

      // Should NOT have auto-saved (manual save took over)
      expect(axios.put).not.toHaveBeenCalled();
    });
  });
});
