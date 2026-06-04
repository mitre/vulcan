import { ref } from "vue";
import { triageReview, bulkTriageReviews } from "../../api/reviewsApi";
import { useCommentsStore } from "../../stores/comments";

export function useCommentTriage() {
  const submitting = ref(false);
  const submitError = ref(null);

  async function triage(reviewId, payload, componentId) {
    submitting.value = true;
    submitError.value = null;
    try {
      const { data: result } = await triageReview(reviewId, payload);
      if (componentId) useCommentsStore().invalidateCache(componentId);
      return result;
    } catch (err) {
      submitError.value = err;
      throw err;
    } finally {
      submitting.value = false;
    }
  }

  async function bulkTriage(reviewIds, payload, componentId) {
    submitting.value = true;
    submitError.value = null;
    try {
      const { data: result } = await bulkTriageReviews(reviewIds, payload);
      if (componentId) useCommentsStore().invalidateCache(componentId);
      return result;
    } catch (err) {
      submitError.value = err;
      throw err;
    } finally {
      submitting.value = false;
    }
  }

  return { triage, bulkTriage, submitting, submitError };
}
