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

    it("reverts to previous state on API error", async () => {
      toggleReaction.mockRejectedValue(new Error("500"));

      const { toggle } = useCommentReactions();
      const apply = vi.fn();
      const prev = { up: 0, down: 0, mine: null };

      await toggle(42, "up", prev, apply);

      expect(apply).toHaveBeenCalledTimes(2);
      expect(apply).toHaveBeenLastCalledWith(prev);
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
