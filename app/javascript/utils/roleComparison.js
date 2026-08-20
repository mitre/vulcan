export const ROLE_HIERARCHY = ["viewer", "author", "reviewer", "admin"];

export function roleGteTo(effectiveRole, requiredRole) {
  if (!effectiveRole || !requiredRole) return false;
  const effectiveIdx = ROLE_HIERARCHY.indexOf(effectiveRole);
  const requiredIdx = ROLE_HIERARCHY.indexOf(requiredRole);
  if (effectiveIdx === -1 || requiredIdx === -1) return false;
  return effectiveIdx >= requiredIdx;
}
