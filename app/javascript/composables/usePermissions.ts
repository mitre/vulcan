/**
 * Permissions Composable
 * Role comparison utilities for permission checks
 *
 * Roles in order of "numeric value":
 * - 'viewer'   => 0
 * - 'author'   => 1
 * - 'reviewer' => 2
 * - 'admin'    => 3
 */

const ROLE_HIERARCHY = ['viewer', 'author', 'reviewer', 'admin'] as const
type Role = typeof ROLE_HIERARCHY[number]

/**
 * Check if a role has at least the minimum required permission level
 */
export function hasPermission(role: string | undefined | null, minRole: Role): boolean {
  if (!role) return false

  const roleIndex = ROLE_HIERARCHY.indexOf(role as Role)
  const minIndex = ROLE_HIERARCHY.indexOf(minRole)

  if (roleIndex === -1 || minIndex === -1) return false

  return roleIndex >= minIndex
}

/**
 * Check if user is at least a viewer
 */
export function isViewer(role: string | undefined | null): boolean {
  return hasPermission(role, 'viewer')
}

/**
 * Check if user is at least an author
 */
export function isAuthor(role: string | undefined | null): boolean {
  return hasPermission(role, 'author')
}

/**
 * Check if user is at least a reviewer
 */
export function isReviewer(role: string | undefined | null): boolean {
  return hasPermission(role, 'reviewer')
}

/**
 * Check if user is an admin
 */
export function isAdmin(role: string | undefined | null): boolean {
  return hasPermission(role, 'admin')
}

/**
 * Composable wrapper for reactive permission checks
 */
export function usePermissions() {
  return {
    hasPermission,
    isViewer,
    isAuthor,
    isReviewer,
    isAdmin,
    ROLE_HIERARCHY,
  }
}
