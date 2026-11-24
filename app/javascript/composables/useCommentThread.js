import { ref, unref, watch } from "vue";
import { useCommentsStore } from "../stores/comments";

/**
 * Lazy-loading reply thread for ONE parent review.
 *
 * `parentReviewIdSource` may be a plain id, a ref, or a getter — and callers
 * whose parent can change MUST pass a reactive source (ref or getter). A host
 * that reuses a single thread instance for whichever comment is active (the
 * triage split view renders one unkeyed CommentThread for the whole queue)
 * only ever changes its prop; a plain value read at setup time would pin every
 * later fetch and cache invalidation to the parent the instance mounted with,
 * i.e. show one comment's replies under another comment.
 *
 * When the parent changes, loaded state is dropped and any in-flight fetch is
 * abandoned, so a late response for the previous parent can never land in the
 * new parent's thread. Re-loading is the host's call (it owns `expanded`).
 */
export function useCommentThread(parentReviewIdSource) {
  // Resolved on every read rather than cached in a computed: the thread must
  // see the parent the host holds right now, even when the source is a getter
  // over something Vue does not track.
  function currentParentReviewId() {
    return typeof parentReviewIdSource === "function"
      ? parentReviewIdSource()
      : unref(parentReviewIdSource);
  }

  const expanded = ref(false);
  const replies = ref([]);
  const loaded = ref(false);
  const loading = ref(false);
  const loadError = ref(false);
  let fetchToken = 0;

  function reset() {
    // Invalidate any in-flight fetch: its result belongs to the old parent.
    fetchToken++;
    replies.value = [];
    loaded.value = false;
    loading.value = false;
    loadError.value = false;
  }

  async function fetch() {
    const parent = currentParentReviewId();
    if (parent == null) return;
    loading.value = true;
    loadError.value = false;
    const token = ++fetchToken;
    try {
      const data = await useCommentsStore().fetchReplies(parent);
      if (token !== fetchToken) return;
      replies.value = data.rows || [];
      loaded.value = true;
    } catch {
      if (token !== fetchToken) return;
      loadError.value = true;
    } finally {
      if (token === fetchToken) loading.value = false;
    }
  }

  async function toggle() {
    expanded.value = !expanded.value;
    if (expanded.value && !loaded.value && !loading.value) {
      await fetch();
    }
  }

  async function refresh() {
    loaded.value = false;
    replies.value = [];
    useCommentsStore().invalidateReplies(currentParentReviewId());
    if (expanded.value) {
      await fetch();
    }
  }

  // Reactive sources (a ref, or a getter over props) redirect the thread as
  // soon as the host switches comments.
  watch(currentParentReviewId, reset);

  return { expanded, replies, loaded, loading, loadError, toggle, fetch, refresh };
}
