import { ref } from "vue";
import { useCommentsStore } from "../../stores/comments";
import { withSubmitting } from "./withSubmitting";

export function useCommentTriage() {
  const submitting = ref(false);
  const submitError = ref(null);

  const triage = withSubmitting(submitting, submitError, (reviewId, payload, componentId) =>
    useCommentsStore().triageComment(componentId, reviewId, payload),
  );

  const bulkTriage = withSubmitting(submitting, submitError, (reviewIds, payload, componentId) =>
    useCommentsStore().bulkTriage(componentId, reviewIds, payload),
  );

  return { triage, bulkTriage, submitting, submitError };
}
