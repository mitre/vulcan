import { ref } from "vue";
import { useCommentsStore } from "../../stores/comments";
import { withSubmitting } from "./withSubmitting";

export function useCommentComposer() {
  const submitting = ref(false);
  const submitError = ref(null);

  const postComment = withSubmitting(submitting, submitError, (componentId, ruleId, data) =>
    useCommentsStore().postComment(componentId, ruleId, data),
  );

  const postComponentComment = withSubmitting(submitting, submitError, (componentId, data) =>
    useCommentsStore().postComponentComment(componentId, data),
  );

  async function postReply(componentId, ruleId, parentId, comment) {
    return postComment(componentId, ruleId, {
      action: "comment",
      comment,
      responding_to_review_id: parentId,
    });
  }

  return { postComment, postComponentComment, postReply, submitting, submitError };
}
