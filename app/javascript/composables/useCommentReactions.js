import { ref } from "vue";
import { toggleReaction } from "../api/reviewsApi";

export function useCommentReactions() {
  const pending = ref(new Set());
  const error = ref(null);

  function optimisticUpdate(prev, kind) {
    const next = { up: prev.up, down: prev.down, mine: null };
    if (prev.mine === kind) {
      next[kind] = Math.max(0, prev[kind] - 1);
      next.mine = null;
    } else if (prev.mine) {
      next[prev.mine] = Math.max(0, prev[prev.mine] - 1);
      next[kind] = prev[kind] + 1;
      next.mine = kind;
    } else {
      next[kind] = prev[kind] + 1;
      next.mine = kind;
    }
    return next;
  }

  async function toggle(reviewId, kind, currentReactions, apply) {
    const key = `${reviewId}:${kind}`;
    if (pending.value.has(key)) return;
    pending.value.add(key);

    const prev = { ...currentReactions };
    error.value = null;
    apply(optimisticUpdate(prev, kind));

    try {
      const { data } = await toggleReaction(reviewId, kind);
      apply(data.reactions);
    } catch (err) {
      apply(prev);
      error.value = err;
      // eslint-disable-next-line no-console
      console.error("[useCommentReactions] Toggle failed:", err);
    } finally {
      pending.value.delete(key);
    }
  }

  return { toggle, optimisticUpdate, pending, error };
}
