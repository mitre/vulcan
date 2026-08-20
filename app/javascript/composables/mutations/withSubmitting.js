export function withSubmitting(submitting, submitError, fn) {
  return async (...args) => {
    submitting.value = true;
    submitError.value = null;
    try {
      return await fn(...args);
    } catch (err) {
      submitError.value = err;
      throw err;
    } finally {
      submitting.value = false;
    }
  };
}
