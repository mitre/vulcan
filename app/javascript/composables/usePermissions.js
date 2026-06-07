import { inject, computed } from "vue";
import { roleGteTo } from "../utils/roleComparison";

export function usePermissions() {
  const effectivePermissions = inject("effectivePermissions", null);

  return {
    effectivePermissions,
    canView: computed(() => roleGteTo(effectivePermissions, "viewer")),
    canEdit: computed(() => roleGteTo(effectivePermissions, "author")),
    canReview: computed(() => roleGteTo(effectivePermissions, "reviewer")),
    canAdmin: computed(() => effectivePermissions === "admin"),
    isMember: computed(() => !!effectivePermissions),
  };
}
