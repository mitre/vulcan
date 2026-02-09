import { ref } from "vue";
import axios from "axios";

/**
 * Composable for rule API actions.
 * Handles lock, unlock, review, save, delete, clone operations.
 *
 * @param {number} componentId - Component ID for review actions
 * @returns {Object} Action methods and state
 */
export function useRuleActions(componentId) {
  // State
  const isLoading = ref(false);
  const lastError = ref(null);

  /**
   * Helper: Post a review action
   */
  async function postReviewAction(rule, action, comment) {
    if (!rule) {
      throw new Error("Rule is required");
    }
    if (!comment?.trim()) {
      throw new Error("Comment is required");
    }

    isLoading.value = true;
    lastError.value = null;

    try {
      const response = await axios.post(`/rules/${rule.id}/reviews`, {
        review: {
          component_id: componentId,
          action: action,
          comment: comment.trim(),
        },
      });
      return response.data;
    } catch (error) {
      lastError.value = error.message;
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * Lock a rule to prevent editing
   */
  async function lockRule(rule, comment) {
    return postReviewAction(rule, "lock_control", comment);
  }

  /**
   * Unlock a rule to allow editing
   */
  async function unlockRule(rule, comment) {
    return postReviewAction(rule, "unlock_control", comment);
  }

  /**
   * Request a review for a rule
   */
  async function requestReview(rule, comment) {
    return postReviewAction(rule, "request_review", comment);
  }

  /**
   * Approve a review
   */
  async function approveReview(rule, comment) {
    return postReviewAction(rule, "approve", comment);
  }

  /**
   * Request changes on a review
   */
  async function requestChanges(rule, comment) {
    return postReviewAction(rule, "request_changes", comment);
  }

  /**
   * Revoke a review request
   */
  async function revokeReview(rule, comment) {
    return postReviewAction(rule, "revoke_review", comment);
  }

  /**
   * Add a comment to a rule
   */
  async function addComment(rule, comment) {
    return postReviewAction(rule, "comment", comment);
  }

  /**
   * Save rule data
   */
  async function saveRule(rule, ruleData) {
    if (!rule) {
      throw new Error("Rule is required");
    }

    isLoading.value = true;
    lastError.value = null;

    try {
      const response = await axios.put(`/rules/${rule.id}`, {
        rule: ruleData,
      });
      return response.data;
    } catch (error) {
      lastError.value = error.message;
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * Delete a rule
   */
  async function deleteRule(rule) {
    if (!rule) {
      throw new Error("Rule is required");
    }

    isLoading.value = true;
    lastError.value = null;

    try {
      const response = await axios.delete(`/rules/${rule.id}`);
      return response.data;
    } catch (error) {
      lastError.value = error.message;
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * Clone/duplicate a rule
   */
  async function cloneRule(rule, cloneData) {
    if (!rule) {
      throw new Error("Rule is required");
    }

    isLoading.value = true;
    lastError.value = null;

    try {
      const response = await axios.post(`/rules/${rule.id}/duplicate`, {
        rule: cloneData,
      });
      return response.data;
    } catch (error) {
      lastError.value = error.message;
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  return {
    // State
    isLoading,
    lastError,

    // Review actions
    lockRule,
    unlockRule,
    requestReview,
    approveReview,
    requestChanges,
    revokeReview,
    addComment,

    // CRUD actions
    saveRule,
    deleteRule,
    cloneRule,
  };
}
