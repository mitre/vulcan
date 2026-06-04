import { ref } from "vue";
import { createRuleReview, createComponentReview } from "../../api/reviewsApi";
import { useCommentsStore } from "../../stores/comments";

export function useCommentComposer() {
  const submitting = ref(false);
  const submitError = ref(null);

  async function postComment(componentId, ruleId, data) {
    submitting.value = true;
    submitError.value = null;
    try {
      const { data: result } = await createRuleReview(ruleId, data);
      useCommentsStore().invalidateCache(componentId);
      return result;
    } catch (err) {
      submitError.value = err;
      throw err;
    } finally {
      submitting.value = false;
    }
  }

  async function postComponentComment(componentId, data) {
    submitting.value = true;
    submitError.value = null;
    try {
      const { data: result } = await createComponentReview(componentId, data);
      useCommentsStore().invalidateCache(componentId);
      return result;
    } catch (err) {
      submitError.value = err;
      throw err;
    } finally {
      submitting.value = false;
    }
  }

  async function postReply(componentId, ruleId, parentId, comment) {
    return postComment(componentId, ruleId, {
      action: "comment",
      comment,
      responding_to_review_id: parentId,
    });
  }

  return { postComment, postComponentComment, postReply, submitting, submitError };
}
