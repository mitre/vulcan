/**
 * UI Component Types
 *
 * Shared types for UI components like ActionMenu, BaseTable, etc.
 */

/**
 * Action item for ActionMenu component
 */
export interface ActionItem {
  /** Unique identifier for the action */
  id: string
  /** Display label for the action */
  label: string
  /** Bootstrap icon class (e.g., 'bi-trash') */
  icon?: string
  /** Color variant for the action */
  variant?: 'default' | 'danger' | 'success' | 'warning'
  /** Whether to show a divider before this item */
  dividerBefore?: boolean
  /** Whether the action is disabled */
  disabled?: boolean
  /** Whether the action is hidden */
  hidden?: boolean
}

/**
 * Column definition for BaseTable component
 */
export interface ColumnDef<T = Record<string, unknown>> {
  /** Key of the item property to display, or 'actions' for action column */
  key: keyof T | 'actions' | string
  /** Display label for column header */
  label?: string
  /** Whether column is sortable */
  sortable?: boolean
  /** CSS class for column */
  class?: string
  /** CSS class for table header cell */
  thClass?: string
  /** CSS class for table data cell */
  tdClass?: string
}

/**
 * Table size variants
 */
export type TableSize = 'sm' | 'md' | 'lg'

/**
 * Button variants commonly used in UI
 */
export type ButtonVariant
  = | 'primary'
    | 'secondary'
    | 'success'
    | 'danger'
    | 'warning'
    | 'info'
    | 'light'
    | 'dark'
    | 'link'
    | 'outline-primary'
    | 'outline-secondary'
    | 'outline-success'
    | 'outline-danger'
    | 'outline-warning'
    | 'outline-info'
    | 'outline-light'
    | 'outline-dark'
