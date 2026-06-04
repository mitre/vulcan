import { ref } from "vue";
import { useCommentsStore } from "../../stores/comments";

export function useCommentTriage() {
  const submitting = ref(false);
  const submitError = ref(null);

  async function triage(reviewId, payload, componentId) {
    submitting.value = true;
    submitError.value = null;
    try {
      return await useCommentsStore().triageComment(componentId, reviewId, payload);
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
      return await useCommentsStore().bulkTriage(componentId, reviewIds, payload);
    } catch (err) {
      submitError.value = err;
      throw err;
    } finally {
      submitting.value = false;
    }
  }

  return { triage, bulkTriage, submitting, submitError };
}
