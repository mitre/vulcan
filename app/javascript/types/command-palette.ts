/**
 * Command Palette Type Definitions
 *
 * Based on Nuxt UI v4 CommandPalette patterns.
 * Used with Reka UI Listbox primitives.
 */

/**
 * Individual item in the command palette
 */
export interface CommandPaletteItem {
  /** Unique identifier */
  id: string | number
  /** Display label */
  label: string
  /** Secondary text */
  description?: string
  /** Tertiary text shown after description (e.g., "In: RHEL 9 STIG") */
  suffix?: string
  /** Bootstrap icon class (e.g., 'bi-folder') */
  icon?: string
  /** Vue Router path for navigation */
  to?: string
  /** External link (opens in new tab) */
  href?: string
  /** Keyboard shortcut display */
  kbds?: string[]
  /** Whether item is disabled */
  disabled?: boolean
  /** Whether item is in loading state */
  loading?: boolean
  /** Custom action when selected */
  onSelect?: () => void
  /** Extra data for custom rendering */
  meta?: Record<string, unknown>
}

/**
 * Group of items with optional filtering behavior
 */
export interface CommandPaletteGroup {
  /** Unique group identifier */
  id: string
  /** Group header label */
  label: string
  /** Group icon */
  icon?: string
  /** Items in this group */
  items: CommandPaletteItem[]
  /**
   * When true, items bypass Fuse.js client-side filtering.
   * Use for server-side filtered results (API responses).
   * @default false
   */
  ignoreFilter?: boolean
  /**
   * Optional post-filter function for custom logic.
   * Called after Fuse.js filtering (if ignoreFilter is false).
   */
  postFilter?: (searchTerm: string, items: CommandPaletteItem[]) => CommandPaletteItem[]
}

/**
 * API response format from /api/search/global
 */
export interface GlobalSearchResponse {
  projects: Array<{
    id: number
    name: string
    description?: string
    components_count?: number
  }>
  components: Array<{
    id: number
    name: string
    version?: string
    release?: string
    project_id: number
    project_name?: string
  }>
  rules: Array<{
    id: number
    rule_id: string
    title: string
    status: string
    component_id: number
  }>
}
