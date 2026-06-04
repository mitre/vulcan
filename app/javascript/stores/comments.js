import { ref, computed } from "vue";
import { defineStore, acceptHMRUpdate } from "pinia";
import { getComments } from "../api/componentsApi";
import {
  getReviewResponses,
  createRuleReview,
  createComponentReview,
  triageReview,
  bulkTriageReviews,
} from "../api/reviewsApi";

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
      authorName: raw.author_name || raw.commenter_display_name || "",
      authorEmail: raw.commenter_email || null,
      text: raw.comment || "",
      section: raw.section || null,
      triageStatus: raw.triage_status || null,
      createdAt: raw.created_at || null,
      reactions: raw.reactions || {},
      responsesCount: raw.responses_count || 0,
      isImported: raw.commenter_imported || false,
      duplicateOfReviewId: raw.duplicate_of_review_id || null,
      addressedByRuleId: raw.addressed_by_rule_id || null,
      addressedByRuleName: raw.addressed_by_rule_name || null,
      adjudicatedAt: raw.adjudicated_at || null,
      ruleDisplayedName: raw.rule_displayed_name || null,
      commentableType: raw.commentable_type || null,
      ruleContent: raw.rule_content || null,
      respondingToReviewId: raw.responding_to_review_id || null,
      groupRuleDisplayedName: raw.group_rule_displayed_name || null,
      parentRuleDisplayedName: raw.parent_rule_displayed_name || null,
    };
  }

  function normalizeRows(data) {
    return {
      ...data,
      rows: (data.rows || []).map(normalizeComment),
    };
  }

  function setCacheEntry(key, value) {
    cache.value = { ...cache.value, [key]: value };
  }

  function removeCacheEntry(key) {
    const { [key]: _, ...rest } = cache.value;
    cache.value = rest;
  }

  function cacheKey(componentId, params) {
    const sorted = Object.keys(params || {})
      .sort()
      .reduce((acc, k) => {
        acc[k] = params[k];
        return acc;
      }, {});
    return `${componentId}:${JSON.stringify(sorted)}`;
  }

  async function fetchComments(componentId, params) {
    const key = cacheKey(componentId, params);
    if (cache.value[key]) return cache.value[key];

    loading.value = true;
    error.value = null;
    try {
      const { data } = await getComments(componentId, params);
      const normalized = normalizeRows(data);
      setCacheEntry(key, normalized);
      return normalized;
    } catch (err) {
      error.value = err;
      throw err;
    } finally {
      loading.value = false;
    }
  }

  async function fetchReplies(componentId, parentReviewId) {
    const key = `${componentId}:replies:${parentReviewId}`;
    if (cache.value[key]) return cache.value[key];

    loading.value = true;
    error.value = null;
    try {
      const { data } = await getReviewResponses(parentReviewId);
      const normalized = normalizeRows(data);
      setCacheEntry(key, normalized);
      return normalized;
    } catch (err) {
      error.value = err;
      throw err;
    } finally {
      loading.value = false;
    }
  }

  async function postComment(componentId, ruleId, data) {
    error.value = null;
    try {
      const { data: result } = await createRuleReview(ruleId, data);
      invalidateCache(componentId);
      return result;
    } catch (err) {
      error.value = err;
      throw err;
    }
  }

  async function postComponentComment(componentId, data) {
    error.value = null;
    try {
      const { data: result } = await createComponentReview(componentId, data);
      invalidateCache(componentId);
      return result;
    } catch (err) {
      error.value = err;
      throw err;
    }
  }

  async function triageComment(componentId, reviewId, payload) {
    error.value = null;
    try {
      const { data: result } = await triageReview(reviewId, payload);
      if (componentId) invalidateCache(componentId);
      return result;
    } catch (err) {
      error.value = err;
      throw err;
    }
  }

  async function bulkTriage(componentId, reviewIds, payload) {
    error.value = null;
    try {
      const { data: result } = await bulkTriageReviews(reviewIds, payload);
      if (componentId) invalidateCache(componentId);
      return result;
    } catch (err) {
      error.value = err;
      throw err;
    }
  }

  function invalidateCache(componentId) {
    const prefix = `${componentId}:`;
    const remaining = {};
    Object.keys(cache.value).forEach((k) => {
      if (!k.startsWith(prefix)) remaining[k] = cache.value[k];
    });
    cache.value = remaining;
  }

  function invalidateReplies(componentId, parentReviewId) {
    removeCacheEntry(`${componentId}:replies:${parentReviewId}`);
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
    fetchReplies,
    postComment,
    postComponentComment,
    triageComment,
    bulkTriage,
    invalidateCache,
    invalidateReplies,
    $reset,
  };
});

if (import.meta.hot) {
  import.meta.hot.accept(acceptHMRUpdate(useCommentsStore, import.meta.hot));
}
