import { ref, computed } from "vue";
import { defineStore } from "pinia";
import { getComments } from "../api/componentsApi";
import { normalizeComment } from "../utils/normalizeComment";
import { getProjectComments } from "../api/projectsApi";
import { getUserComments } from "../api/usersApi";
import {
  getReviewResponses,
  createRuleReview,
  createComponentReview,
  triageReview,
  bulkTriageReviews,
  adjudicateReview,
  mergeReviews,
  adminDestroyReview,
  moveReviewToRule,
  adminWithdrawReview,
  adminRestoreReview,
} from "../api/reviewsApi";

const MAX_CACHE_ENTRIES = 50;

export const useCommentsStore = defineStore("comments", () => {
  const cache = ref({});
  const loadingCount = ref(0);
  const loading = computed(() => loadingCount.value > 0);
  const error = ref(null);

  const commentCount = computed(() =>
    Object.values(cache.value).reduce((sum, v) => sum + (v.rows?.length || 0), 0),
  );

  function normalizePagination(raw) {
    if (!raw) return raw;
    return {
      ...raw,
      perPage: raw.per_page,
      totalRows: raw.total,
      totalComments: raw.total_comments,
    };
  }

  function normalizeRows(data) {
    return {
      ...data,
      rows: (data.rows || []).map(normalizeComment),
      pagination: normalizePagination(data.pagination),
      statusCounts: data.status_counts,
    };
  }

  function setCacheEntry(key, value) {
    const keys = Object.keys(cache.value);
    if (keys.length >= MAX_CACHE_ENTRIES) {
      const { [keys[0]]: _, ...rest } = cache.value;
      cache.value = { ...rest, [key]: value };
    } else {
      cache.value = { ...cache.value, [key]: value };
    }
  }

  function removeCacheEntry(key) {
    const { [key]: _, ...rest } = cache.value;
    cache.value = rest;
  }

  function cacheKey(componentId, params) {
    // Explicit code-unit comparator: cache keys need deterministic,
    // locale-independent ordering.
    const sorted = Object.keys(params || {})
      .sort((a, b) => (a > b) - (a < b))
      .reduce((acc, k) => {
        acc[k] = params[k];
        return acc;
      }, {});
    return `${componentId}:${JSON.stringify(sorted)}`;
  }

  async function fetchAndNormalize(apiFn, ...apiArgs) {
    loadingCount.value++;
    error.value = null;
    try {
      const { data } = await apiFn(...apiArgs);
      return normalizeRows(data);
    } catch (err) {
      error.value = err;
      throw err;
    } finally {
      loadingCount.value--;
    }
  }

  async function fetchComments(componentId, params) {
    const key = cacheKey(componentId, params);
    if (cache.value[key]) return cache.value[key];
    const result = await fetchAndNormalize(getComments, componentId, params);
    setCacheEntry(key, result);
    return result;
  }

  async function fetchReplies(componentId, parentReviewId) {
    const key = `${componentId}:replies:${parentReviewId}`;
    if (cache.value[key]) return cache.value[key];
    const result = await fetchAndNormalize(getReviewResponses, parentReviewId);
    setCacheEntry(key, result);
    return result;
  }

  async function mutateAndInvalidate(apiFn, apiArgs, componentId) {
    error.value = null;
    try {
      const { data: result } = await apiFn(...apiArgs);
      if (componentId) invalidateCache(componentId);
      return result;
    } catch (err) {
      error.value = err;
      throw err;
    }
  }

  async function postComment(componentId, ruleId, data) {
    return mutateAndInvalidate(createRuleReview, [ruleId, data], componentId);
  }

  async function postComponentComment(componentId, data) {
    return mutateAndInvalidate(createComponentReview, [componentId, data], componentId);
  }

  async function triageComment(componentId, reviewId, payload) {
    return mutateAndInvalidate(triageReview, [reviewId, payload], componentId);
  }

  async function bulkTriage(componentId, reviewIds, payload) {
    return mutateAndInvalidate(bulkTriageReviews, [reviewIds, payload], componentId);
  }

  async function adjudicateComment(componentId, reviewId) {
    return mutateAndInvalidate(adjudicateReview, [reviewId], componentId);
  }

  async function mergeComments(componentId, reviewIds, survivorId) {
    return mutateAndInvalidate(mergeReviews, [reviewIds, survivorId], componentId);
  }

  async function adminAction(componentId, reviewId, action, params) {
    const apiFnMap = {
      "hard-delete": () => adminDestroyReview(reviewId, params.audit_comment),
      "move-to-rule": () => moveReviewToRule(reviewId, params.rule_id, params.audit_comment),
      "force-withdraw": () => adminWithdrawReview(reviewId, params.audit_comment),
      restore: () => adminRestoreReview(reviewId, params.audit_comment),
    };
    const apiFn = apiFnMap[action];
    if (!apiFn) throw new Error(`Unknown admin action: ${action}`);
    return mutateAndInvalidate(() => apiFn(), [], componentId);
  }

  async function fetchProjectComments(projectId, params) {
    return fetchAndNormalize(getProjectComments, projectId, params);
  }

  async function fetchUserComments(userId, params) {
    return fetchAndNormalize(getUserComments, userId, params);
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
    loadingCount.value = 0;
    error.value = null;
  }

  return {
    cache,
    loading,
    error,
    commentCount,
    normalizeComment,
    fetchComments,
    fetchProjectComments,
    fetchUserComments,
    fetchReplies,
    postComment,
    postComponentComment,
    triageComment,
    bulkTriage,
    adjudicateComment,
    mergeComments,
    adminAction,
    invalidateCache,
    invalidateReplies,
    $reset,
  };
});
