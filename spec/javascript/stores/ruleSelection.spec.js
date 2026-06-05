import { describe, it, expect, beforeEach, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useRuleSelectionStore } from "@/stores/ruleSelection";
import { createTestRouter } from "@test/support/routerTestHelper";

describe("useRuleSelectionStore", () => {
  let store;
  let router;

  beforeEach(() => {
    setActivePinia(createPinia());
    localStorage.clear();
    router = createTestRouter([
      { path: "/", name: "editor-root" },
      { path: "/rules/:ruleId", name: "rule", props: true },
    ]);
    store = useRuleSelectionStore();
    store.init(router, 42);
  });

  describe("selectRule", () => {
    it("updates selectedRuleId", () => {
      store.selectRule(7);
      expect(store.selectedRuleId).toBe(7);
    });

    it("adds ruleId to openRuleIds", () => {
      store.selectRule(7);
      expect(store.openRuleIds).toContain(7);
    });

    it("calls router.push with rule route", () => {
      const pushSpy = vi.spyOn(router, "push");
      store.selectRule(7);
      expect(pushSpy).toHaveBeenCalledWith({
        name: "rule",
        params: { ruleId: "7" },
      });
    });

    it("does not duplicate in openRuleIds on re-select", () => {
      store.selectRule(7);
      store.selectRule(7);
      expect(store.openRuleIds.filter((id) => id === 7)).toHaveLength(1);
    });

    it("persists selectedRuleId to localStorage", () => {
      store.selectRule(7);
      expect(localStorage.getItem("selectedRuleId-42")).toBe("7");
    });
  });

  describe("deselectRule", () => {
    it("removes ruleId from openRuleIds", () => {
      store.selectRule(7);
      store.deselectRule(7);
      expect(store.openRuleIds).not.toContain(7);
    });

    it("clears selectedRuleId when deselecting the active rule", () => {
      store.selectRule(7);
      store.deselectRule(7);
      expect(store.selectedRuleId).toBeNull();
    });

    it("does not clear selectedRuleId when deselecting a different rule", () => {
      store.selectRule(7);
      store.selectRule(8);
      store.deselectRule(7);
      expect(store.selectedRuleId).toBe(8);
    });
  });

  describe("closeAllRules", () => {
    it("clears openRuleIds and selectedRuleId", () => {
      store.selectRule(7);
      store.selectRule(8);
      store.closeAllRules();

      expect(store.openRuleIds).toHaveLength(0);
      expect(store.selectedRuleId).toBeNull();
    });

    it("clears localStorage", () => {
      store.selectRule(7);
      store.closeAllRules();
      expect(localStorage.getItem("selectedRuleId-42")).toBe("null");
    });
  });

  describe("isRuleOpen", () => {
    it("returns true for open rules", () => {
      store.selectRule(7);
      expect(store.isRuleOpen(7)).toBe(true);
    });

    it("returns false for closed rules", () => {
      expect(store.isRuleOpen(99)).toBe(false);
    });
  });

  describe("localStorage persistence", () => {
    it("restores selectedRuleId from localStorage on init", () => {
      localStorage.setItem("selectedRuleId-42", "99");

      const store2 = useRuleSelectionStore();
      store2.init(router, 42);

      expect(store2.selectedRuleId).toBe(99);
    });

    it("restores openRuleIds from localStorage on init", () => {
      localStorage.setItem("openRuleIds", JSON.stringify([10, 20]));

      const store2 = useRuleSelectionStore();
      store2.init(router, 42);

      expect(store2.openRuleIds).toEqual([10, 20]);
    });
  });

  describe("$reset", () => {
    it("clears all state for page teardown", () => {
      store.selectRule(7);
      store.$reset();

      expect(store.selectedRuleId).toBeNull();
      expect(store.openRuleIds).toHaveLength(0);
    });
  });
});
