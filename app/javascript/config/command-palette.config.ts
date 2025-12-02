/**
 * Command Palette Configuration
 *
 * Static quick actions that are filtered client-side with Fuse.js.
 * These are always available in the command palette.
 */

import type { CommandPaletteItem } from '@/types/command-palette'

/**
 * Quick actions available in the command palette.
 * Filtered client-side using Fuse.js (ignoreFilter: false).
 */
export const QUICK_ACTIONS: CommandPaletteItem[] = [
  // Navigation
  {
    id: 'new-project',
    label: 'New Project',
    description: 'Create a new project',
    icon: 'bi-plus-circle',
    to: '/projects/new',
  },
  {
    id: 'view-projects',
    label: 'View All Projects',
    description: 'Browse all projects',
    icon: 'bi-folder',
    to: '/projects',
  },
  {
    id: 'view-components',
    label: 'View All Components',
    description: 'Browse all components',
    icon: 'bi-box',
    to: '/components',
  },
  {
    id: 'browse-stigs',
    label: 'Browse STIGs',
    description: 'View published STIGs',
    icon: 'bi-file-earmark-text',
    to: '/stigs',
  },
  {
    id: 'browse-srgs',
    label: 'Browse SRGs',
    description: 'View Security Requirements Guides',
    icon: 'bi-shield-check',
    to: '/srgs',
  },
  // User actions (available to all signed-in users)
  {
    id: 'user-profile',
    label: 'User Profile',
    description: 'Edit your profile settings',
    icon: 'bi-person',
    to: '/profile',
  },
  {
    id: 'sign-out',
    label: 'Sign Out',
    description: 'Log out of your account',
    icon: 'bi-box-arrow-right',
    to: '/users/sign_out',
  },
]

/**
 * Admin actions - shown only for admin users.
 * Add to quick actions conditionally based on user role.
 */
export const ADMIN_ACTIONS: CommandPaletteItem[] = [
  {
    id: 'manage-users',
    label: 'Manage Users',
    description: 'User administration and management',
    icon: 'bi-people',
    to: '/users',
  },
  {
    id: 'user-management',
    label: 'User Management',
    description: 'Administer user accounts',
    icon: 'bi-person-gear',
    to: '/users',
  },
  {
    id: 'upload-srg',
    label: 'Upload SRG',
    description: 'Import a Security Requirements Guide',
    icon: 'bi-upload',
    to: '/srgs',
  },
  {
    id: 'upload-stig',
    label: 'Upload STIG',
    description: 'Import a published STIG',
    icon: 'bi-upload',
    to: '/stigs',
  },
]

/**
 * Get quick actions based on user role.
 * @param isAdmin - Whether the current user is an admin
 */
export function getQuickActions(isAdmin: boolean = false): CommandPaletteItem[] {
  if (isAdmin) {
    return [...QUICK_ACTIONS, ...ADMIN_ACTIONS]
  }
  return QUICK_ACTIONS
}
