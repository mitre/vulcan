import { ref } from "vue";
import { useCommentsStore } from "../stores/comments";

export function useCommentThread(parentReviewId) {
  const expanded = ref(false);
  const replies = ref([]);
  const loaded = ref(false);
  const loading = ref(false);
  const loadError = ref(false);
  let fetchToken = 0;

  async function fetch() {
    loading.value = true;
    loadError.value = false;
    const token = ++fetchToken;
    try {
      const data = await useCommentsStore().fetchReplies(parentReviewId);
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
    const store = useCommentsStore();
    delete store.cache[`replies:${parentReviewId}`];
    if (expanded.value) {
      await fetch();
    }
  }

  return { expanded, replies, loaded, loading, loadError, toggle, fetch, refresh };
}
