import { ref, computed } from "vue";
import { defineStore, acceptHMRUpdate } from "pinia";
import { getComments } from "../api/componentsApi";

export const useCommentsStore = defineStore("comments", () => {
  const cache = ref({});
  const loading = ref(false);
  const error = ref(null);

  const commentCount = computed(() =>
    Object.values(cache.value).reduce((sum, v) => sum + (v.rows?.length || 0), 0),
  );

  function normalizeComment(raw) {
    return {
      id: raw.id,
      ruleId: raw.rule_id,
      authorName: raw.author_name || raw.commenter_display_name,
      authorEmail: raw.commenter_email,
      text: raw.comment,
      section: raw.section,
      triageStatus: raw.triage_status,
      createdAt: raw.created_at,
      reactions: raw.reactions || {},
      responsesCount: raw.responses_count || 0,
      isImported: raw.commenter_imported || false,
      duplicateOfReviewId: raw.duplicate_of_review_id,
      addressedByRuleId: raw.addressed_by_rule_id,
      addressedByRuleName: raw.addressed_by_rule_name,
      adjudicatedAt: raw.adjudicated_at,
      ruleDisplayedName: raw.rule_displayed_name,
      commentableType: raw.commentable_type,
    };
  }

  function cacheKey(componentId, params) {
    return `${componentId}:${JSON.stringify(params || {})}`;
  }

  async function fetchComments(componentId, params) {
    const key = cacheKey(componentId, params);
    if (cache.value[key]) return cache.value[key];

    loading.value = true;
    error.value = null;
    try {
      const { data } = await getComments(componentId, params);
      cache.value[key] = data;
      return data;
    } catch (err) {
      error.value = err;
      throw err;
    } finally {
      loading.value = false;
    }
  }

  function invalidateCache(componentId) {
    Object.keys(cache.value)
      .filter((k) => k.startsWith(`${componentId}:`))
      .forEach((k) => delete cache.value[k]);
  }

  function $reset() {
    cache.value = {};
    loading.value = false;
    error.value = null;
  }

  return {
    cache,
    loading,
    error,
    commentCount,
    normalizeComment,
    fetchComments,
    invalidateCache,
    $reset,
  };
});

if (import.meta.hot) {
  import.meta.hot.accept(acceptHMRUpdate(useCommentsStore, import.meta.hot));
}
