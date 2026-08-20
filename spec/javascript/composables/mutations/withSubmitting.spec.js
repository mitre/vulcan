import { describe, it, expect, vi } from "vitest";
import { ref } from "vue";
import { withSubmitting } from "@/composables/mutations/withSubmitting";

describe("withSubmitting", () => {
  it("sets submitting=true during execution and false after", async () => {
    const submitting = ref(false);
    const submitError = ref(null);
    const fn = vi.fn(() => Promise.resolve("ok"));

    const wrapped = withSubmitting(submitting, submitError, fn);

    let duringValue;
    fn.mockImplementation(() => {
      duringValue = submitting.value;
      return Promise.resolve("ok");
    });

    await wrapped("arg1");
    expect(duringValue).toBe(true);
    expect(submitting.value).toBe(false);
  });

  it("returns the resolved value from the wrapped function", async () => {
    const submitting = ref(false);
    const submitError = ref(null);
    const wrapped = withSubmitting(submitting, submitError, () => Promise.resolve({ id: 42 }));

    const result = await wrapped();
    expect(result).toEqual({ id: 42 });
  });

  it("sets submitError on failure and rethrows", async () => {
    const submitting = ref(false);
    const submitError = ref(null);
    const err = new Error("403 Forbidden");
    const wrapped = withSubmitting(submitting, submitError, () => Promise.reject(err));

    await expect(wrapped()).rejects.toThrow("403 Forbidden");
    expect(submitError.value).toBe(err);
    expect(submitting.value).toBe(false);
  });

  it("clears submitError on a successful call after a previous failure", async () => {
    const submitting = ref(false);
    const submitError = ref(new Error("stale"));
    const wrapped = withSubmitting(submitting, submitError, () => Promise.resolve("ok"));

    await wrapped();
    expect(submitError.value).toBeNull();
  });

  it("passes all arguments through to the wrapped function", async () => {
    const submitting = ref(false);
    const submitError = ref(null);
    const fn = vi.fn(() => Promise.resolve());
    const wrapped = withSubmitting(submitting, submitError, fn);

    await wrapped("a", 2, { key: "val" });
    expect(fn).toHaveBeenCalledWith("a", 2, { key: "val" });
  });
});
