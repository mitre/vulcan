import { describe, it, expect, vi, beforeEach } from "vitest";
import { useConfirmRelease, RELEASE_CONFIRM_COPY } from "@/composables/useConfirmRelease";
import { patchComponent } from "@/api/componentsApi";

vi.mock("@/api/componentsApi", () => ({
  patchComponent: vi.fn(),
}));

// REQUIREMENT: useConfirmRelease must replicate ConfirmComponentReleaseMixin
// behavior with the codebase's composable-confirmation pattern
// (useDeleteConfirmation shape: state + declarative modal in consumer):
//   - releasable guard: non-releasable components never open the dialog
//   - confirm releases via patchComponent(id, { released: true })
//   - release CANNOT be undone — error keeps the dialog open for retry,
//     success closes and resets
//   - dialog copy is exported once so both consumers share one source of truth
describe("useConfirmRelease", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("initial state", () => {
    it("starts closed with no pending component", () => {
      const { showModal, isReleasing, componentToRelease } = useConfirmRelease();
      expect(showModal.value).toBe(false);
      expect(isReleasing.value).toBe(false);
      expect(componentToRelease.value).toBe(null);
    });
  });

  describe("requestRelease", () => {
    it("opens the dialog for a releasable component and returns true", () => {
      const { requestRelease, showModal, componentToRelease } = useConfirmRelease();
      const component = { id: 42, releasable: true };

      expect(requestRelease(component)).toBe(true);
      expect(showModal.value).toBe(true);
      expect(componentToRelease.value).toEqual({ id: 42, releasable: true });
    });

    it("refuses non-releasable components (mixin guard parity) and returns false", () => {
      const { requestRelease, showModal, componentToRelease } = useConfirmRelease();

      expect(requestRelease({ id: 42, releasable: false })).toBe(false);
      expect(showModal.value).toBe(false);
      expect(componentToRelease.value).toBe(null);
    });

    it("refuses null/undefined components safely", () => {
      const { requestRelease, showModal } = useConfirmRelease();

      expect(requestRelease(null)).toBe(false);
      expect(requestRelease(undefined)).toBe(false);
      expect(showModal.value).toBe(false);
    });
  });

  describe("cancel", () => {
    it("closes the dialog and clears all state", () => {
      const { requestRelease, cancel, showModal, componentToRelease, isReleasing } =
        useConfirmRelease();
      requestRelease({ id: 42, releasable: true });

      cancel();

      expect(showModal.value).toBe(false);
      expect(componentToRelease.value).toBe(null);
      expect(isReleasing.value).toBe(false);
    });
  });

  describe("confirm", () => {
    it("PATCHes released: true for the pending component and resets on success", async () => {
      const apiResponse = { data: { toast: { title: "Released" } } };
      patchComponent.mockResolvedValue(apiResponse);

      const { requestRelease, confirm, showModal, componentToRelease, isReleasing } =
        useConfirmRelease();
      requestRelease({ id: 42, releasable: true });

      const result = await confirm();

      expect(patchComponent).toHaveBeenCalledExactlyOnceWith(42, { released: true });
      expect(result.success).toBe(true);
      expect(result.response).toBe(apiResponse);
      expect(result.error).toBe(null);
      expect(showModal.value).toBe(false);
      expect(componentToRelease.value).toBe(null);
      expect(isReleasing.value).toBe(false);
    });

    it("returns failure without calling the API when nothing is pending", async () => {
      const { confirm } = useConfirmRelease();

      const result = await confirm();

      expect(patchComponent).not.toHaveBeenCalled();
      expect(result.success).toBe(false);
      expect(result.error).toBe(null);
    });

    it("keeps the dialog open with the component retained when the API fails", async () => {
      const apiError = new Error("422 Unprocessable");
      patchComponent.mockRejectedValue(apiError);

      const { requestRelease, confirm, showModal, componentToRelease, isReleasing } =
        useConfirmRelease();
      requestRelease({ id: 42, releasable: true });

      const result = await confirm();

      expect(result.success).toBe(false);
      expect(result.error).toBe(apiError);
      expect(showModal.value).toBe(true);
      expect(componentToRelease.value).toEqual({ id: 42, releasable: true });
      expect(isReleasing.value).toBe(false);
    });

    it("guards against double-submit while a release is in flight", async () => {
      let resolveApi;
      patchComponent.mockReturnValue(new Promise((resolve) => (resolveApi = resolve)));

      const { requestRelease, confirm, isReleasing } = useConfirmRelease();
      requestRelease({ id: 42, releasable: true });

      const first = confirm();
      expect(isReleasing.value).toBe(true);

      const second = await confirm();
      expect(second.success).toBe(false);
      expect(patchComponent).toHaveBeenCalledTimes(1);

      resolveApi({ data: {} });
      const firstResult = await first;
      expect(firstResult.success).toBe(true);
    });
  });

  describe("RELEASE_CONFIRM_COPY", () => {
    it("exports the dialog copy from the original mixin as one source of truth", () => {
      expect(RELEASE_CONFIRM_COPY.title).toBe("Release Component");
      expect(RELEASE_CONFIRM_COPY.okTitle).toBe("Release Component");
      expect(RELEASE_CONFIRM_COPY.okVariant).toBe("success");
      expect(RELEASE_CONFIRM_COPY.cancelTitle).toBe("Cancel");
      expect(RELEASE_CONFIRM_COPY.body).toContain(
        "Are you sure you want to release this component?",
      );
      expect(RELEASE_CONFIRM_COPY.body).toContain("This cannot be undone");
    });
  });
});
