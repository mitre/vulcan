import { describe, it, expect, vi, beforeEach } from "vitest";
import { useCommentReactions } from "@/composables/useCommentReactions";
import { toggleReaction } from "@/api/reviewsApi";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
    defaults: { headers: { common: {} } },
  },
}));

vi.mock("@/api/reviewsApi", () => ({
  toggleReaction: vi.fn(),
}));

describe("useCommentReactions", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns toggle function and pending set", () => {
    const { toggle, pending } = useCommentReactions();
    expect(typeof toggle).toBe("function");
    expect(pending.value).toBeInstanceOf(Set);
    expect(pending.value.size).toBe(0);
  });

  describe("optimistic toggle", () => {
    it("increments count and sets mine on first toggle", () => {
      const { optimisticUpdate } = useCommentReactions();
      const prev = { up: 0, down: 0, mine: null };
      const next = optimisticUpdate(prev, "up");
      expect(next.up).toBe(1);
      expect(next.mine).toBe("up");
    });

    it("decrements and clears mine when toggling same kind", () => {
      const { optimisticUpdate } = useCommentReactions();
      const prev = { up: 1, down: 0, mine: "up" };
      const next = optimisticUpdate(prev, "up");
      expect(next.up).toBe(0);
      expect(next.mine).toBeNull();
    });

    it("switches from one kind to another", () => {
      const { optimisticUpdate } = useCommentReactions();
      const prev = { up: 1, down: 0, mine: "up" };
      const next = optimisticUpdate(prev, "down");
      expect(next.up).toBe(0);
      expect(next.down).toBe(1);
      expect(next.mine).toBe("down");
    });

    it("never goes below zero", () => {
      const { optimisticUpdate } = useCommentReactions();
      const prev = { up: 0, down: 0, mine: "up" };
      const next = optimisticUpdate(prev, "up");
      expect(next.up).toBe(0);
    });
  });

  describe("toggle (API call)", () => {
    it("calls API and applies server response", async () => {
      const serverReactions = { up: 1, down: 0, mine: "up" };
      toggleReaction.mockResolvedValue({ data: { reactions: serverReactions } });

      const { toggle } = useCommentReactions();
      const apply = vi.fn();
      const prev = { up: 0, down: 0, mine: null };

      await toggle(42, "up", prev, apply);

      expect(toggleReaction).toHaveBeenCalledWith(42, "up");
      expect(apply).toHaveBeenCalledTimes(2);
      expect(apply).toHaveBeenLastCalledWith(serverReactions);
    });

    // Error-path tests spy console.error and ASSERT the log — the composable
    // intentionally logs failures, so the test pins that contract instead of
    // leaking it as suite stderr noise.
    it("reverts to previous state on API error", async () => {
      const consoleSpy = vi.spyOn(console, "error").mockImplementation(() => {});
      toggleReaction.mockRejectedValue(new Error("500"));

      const { toggle } = useCommentReactions();
      const apply = vi.fn();
      const prev = { up: 0, down: 0, mine: null };

      await toggle(42, "up", prev, apply);

      expect(apply).toHaveBeenCalledTimes(2);
      expect(apply).toHaveBeenLastCalledWith(prev);
      expect(consoleSpy).toHaveBeenCalledWith(
        "[useCommentReactions] Toggle failed:",
        expect.any(Error),
      );
      consoleSpy.mockRestore();
    });

    it("sets error ref on API failure", async () => {
      const consoleSpy = vi.spyOn(console, "error").mockImplementation(() => {});
      const apiError = new Error("403 Forbidden");
      toggleReaction.mockRejectedValue(apiError);

      const { toggle, error } = useCommentReactions();
      const apply = vi.fn();
      const prev = { up: 0, down: 0, mine: null };

      await toggle(42, "up", prev, apply);

      expect(error.value).toBe(apiError);
      expect(consoleSpy).toHaveBeenCalledWith("[useCommentReactions] Toggle failed:", apiError);
      consoleSpy.mockRestore();
    });

    it("clears error ref on successful toggle", async () => {
      const consoleSpy = vi.spyOn(console, "error").mockImplementation(() => {});
      toggleReaction.mockRejectedValueOnce(new Error("500"));
      toggleReaction.mockResolvedValueOnce({
        data: { reactions: { up: 1, down: 0, mine: "up" } },
      });

      const { toggle, error } = useCommentReactions();
      const apply = vi.fn();
      const prev = { up: 0, down: 0, mine: null };

      await toggle(42, "up", prev, apply);
      expect(error.value).toBeInstanceOf(Error);

      await toggle(42, "up", prev, apply);
      expect(error.value).toBeNull();
      expect(consoleSpy).toHaveBeenCalledTimes(1);
      consoleSpy.mockRestore();
    });

    it("prevents duplicate toggles while pending", async () => {
      let resolvePromise;
      toggleReaction.mockReturnValue(
        new Promise((resolve) => {
          resolvePromise = resolve;
        }),
      );

      const { toggle, pending } = useCommentReactions();
      const apply = vi.fn();
      const prev = { up: 0, down: 0, mine: null };

      const p1 = toggle(42, "up", prev, apply);
      expect(pending.value.has("42:up")).toBe(true);

      await toggle(42, "up", prev, apply);
      expect(toggleReaction).toHaveBeenCalledTimes(1);

      resolvePromise({ data: { reactions: prev } });
      await p1;
      expect(pending.value.has("42:up")).toBe(false);
    });
  });
});
