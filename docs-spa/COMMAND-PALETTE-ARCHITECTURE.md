# Command Palette Architecture

## Overview

The Command Palette provides global search and quick navigation across Vulcan. It combines:
- **Quick Actions** - Static navigation items (client-side Fuse.js filtering)
- **Global Search** - Server-side search across projects, components, requirements (pg_search)

Built with:
- **Reka UI** - Listbox primitives (not Combobox)
- **Bootstrap 5** - Styling
- **Vue 3 Composition API** - Composables and Pinia stores
- **@vueuse/integrations** - useFuse for client-side fuzzy search

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              App.vue                                     │
│                                                                          │
│   Cmd+J / Ctrl+J  ──────────►  CommandPalette.vue                       │
│                                      │                                   │
│                                      ▼                                   │
│                         ┌────────────────────────┐                      │
│                         │  useCommandPalette()   │                      │
│                         │  - open: boolean       │                      │
│                         │  - searchTerm: string  │                      │
│                         └───────────┬────────────┘                      │
│                                     │                                    │
│                                     ▼                                    │
│                         ┌────────────────────────┐                      │
│                         │  useGlobalSearch()     │                      │
│                         │  - groups: computed    │                      │
│                         │  - loading: boolean    │                      │
│                         └───────────┬────────────┘                      │
│                                     │                                    │
│               ┌─────────────────────┼─────────────────────┐             │
│               ▼                     ▼                     ▼             │
│     ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐    │
│     │  Quick Actions  │   │   API Search    │   │  Future Groups  │    │
│     │  (Fuse.js)      │   │  (pg_search)    │   │  (extensible)   │    │
│     │                 │   │                 │   │                 │    │
│     │  ignoreFilter:  │   │  ignoreFilter:  │   │  ignoreFilter:  │    │
│     │  false          │   │  true           │   │  true/false     │    │
│     └─────────────────┘   └─────────────────┘   └─────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### 1. User Opens Command Palette
```
User presses Cmd+J
    ↓
useCommandPalette.open = true
    ↓
CommandPalette.vue renders Modal
    ↓
Input auto-focuses
```

### 2. User Types Search Query
```
User types "kubernetes"
    ↓
searchTerm.value = "kubernetes"
    ↓
useGlobalSearch watches searchTerm
    ↓
Debounce 300ms
    ↓
Fetch /api/search/global?q=kubernetes
    ↓
Transform response to CommandPaletteGroup[]
    ↓
groups.value updated
    ↓
ListboxContent re-renders with results
```

### 3. User Selects Item
```
User clicks item or presses Enter
    ↓
onSelect(item) called
    ↓
item.onSelect?.() or router.push(item.to)
    ↓
open.value = false
    ↓
Modal closes, searchTerm resets
```

---

## File Structure

```
app/javascript/
├── composables/
│   ├── useCommandPalette.ts      # UI state (open, shortcuts)
│   └── useGlobalSearch.ts        # API + group composition
├── components/shared/
│   └── CommandPalette.vue        # Main component
├── types/
│   └── command-palette.ts        # TypeScript interfaces
└── config/
    └── command-palette.config.ts # Static actions, icons config
```

---

## Type Definitions

```typescript
// types/command-palette.ts

/**
 * Individual item in the command palette
 */
export interface CommandPaletteItem {
  id: string | number
  label: string
  description?: string
  icon?: string           // Bootstrap icon class (e.g., 'bi-folder')
  to?: string             // Vue Router path
  href?: string           // External link
  disabled?: boolean
  loading?: boolean
  onSelect?: () => void   // Custom action
  meta?: Record<string, any>  // Extra data for custom rendering
}

/**
 * Group of items with optional filtering behavior
 */
export interface CommandPaletteGroup {
  id: string
  label: string
  icon?: string
  items: CommandPaletteItem[]
  /**
   * When true, items bypass Fuse.js filtering.
   * Use for server-side filtered results.
   * @default false
   */
  ignoreFilter?: boolean
  /**
   * Optional post-filter function for custom logic
   */
  postFilter?: (searchTerm: string, items: CommandPaletteItem[]) => CommandPaletteItem[]
}
```

---

## Composables

### useCommandPalette.ts

Manages UI state only - no data fetching.

```typescript
// composables/useCommandPalette.ts
import { ref, watch } from 'vue'
import { useMagicKeys, whenever } from '@vueuse/core'

export function useCommandPalette() {
  const open = ref(false)
  const searchTerm = ref('')

  // Keyboard shortcut: Cmd+J (Mac) or Ctrl+J (Windows/Linux)
  const { meta_j, ctrl_j } = useMagicKeys({
    passive: false,
    onEventFired(e) {
      if ((e.metaKey || e.ctrlKey) && e.key === 'j') {
        e.preventDefault()
      }
    },
  })

  whenever(meta_j, () => { open.value = true })
  whenever(ctrl_j, () => { open.value = true })

  // Reset search when closing
  watch(open, (isOpen) => {
    if (!isOpen) {
      searchTerm.value = ''
    }
  })

  function toggle() {
    open.value = !open.value
  }

  function close() {
    open.value = false
  }

  return {
    open,
    searchTerm,
    toggle,
    close,
  }
}
```

### useGlobalSearch.ts

Handles API calls and composes groups.

```typescript
// composables/useGlobalSearch.ts
import { computed, ref, watch, type Ref } from 'vue'
import { useDebounceFn } from '@vueuse/core'
import { useRouter } from 'vue-router'
import type { CommandPaletteGroup, CommandPaletteItem } from '@/types/command-palette'
import { QUICK_ACTIONS } from '@/config/command-palette.config'

export function useGlobalSearch(searchTerm: Ref<string>) {
  const router = useRouter()
  const loading = ref(false)
  const error = ref<string | null>(null)

  // API results
  const projects = ref<CommandPaletteItem[]>([])
  const components = ref<CommandPaletteItem[]>([])
  const rules = ref<CommandPaletteItem[]>([])

  // Debounced API fetch
  const fetchResults = useDebounceFn(async (query: string) => {
    if (query.length < 2) {
      projects.value = []
      components.value = []
      rules.value = []
      return
    }

    loading.value = true
    error.value = null

    try {
      const response = await fetch(
        `/api/search/global?q=${encodeURIComponent(query)}&limit=10`,
        { credentials: 'same-origin' }
      )

      if (!response.ok) throw new Error('Search failed')

      const data = await response.json()

      // Transform to CommandPaletteItem format
      projects.value = (data.projects || []).map((p: any) => ({
        id: `project-${p.id}`,
        label: p.name,
        description: p.description || `${p.components_count} components`,
        icon: 'bi-folder',
        to: `/projects/${p.id}`,
        onSelect: () => router.push(`/projects/${p.id}`),
      }))

      components.value = (data.components || []).map((c: any) => ({
        id: `component-${c.id}`,
        label: c.name,
        description: c.version ? `V${c.version}R${c.release || '0'}` : c.project_name,
        icon: 'bi-box',
        to: `/components/${c.id}`,
        onSelect: () => router.push(`/components/${c.id}`),
      }))

      rules.value = (data.rules || []).map((r: any) => ({
        id: `rule-${r.id}`,
        label: r.rule_id,
        description: r.title,
        icon: 'bi-shield-check',
        to: `/components/${r.component_id}/controls?rule=${r.id}`,
        onSelect: () => router.push(`/components/${r.component_id}/controls?rule=${r.id}`),
      }))
    } catch (err) {
      error.value = err instanceof Error ? err.message : 'Search failed'
      console.error('Global search error:', err)
    } finally {
      loading.value = false
    }
  }, 300)

  // Watch searchTerm and fetch
  watch(searchTerm, (query) => {
    fetchResults(query)
  })

  // Compose groups
  const groups = computed<CommandPaletteGroup[]>(() => {
    const result: CommandPaletteGroup[] = []

    // Quick Actions - always shown, Fuse.js filtered
    result.push({
      id: 'actions',
      label: 'Quick Actions',
      icon: 'bi-lightning',
      items: QUICK_ACTIONS,
      ignoreFilter: false,  // Fuse.js filters these
    })

    // API results - only shown when searching, already filtered by server
    if (searchTerm.value.length >= 2) {
      if (projects.value.length) {
        result.push({
          id: 'projects',
          label: 'Projects',
          icon: 'bi-folder',
          items: projects.value,
          ignoreFilter: true,  // Server already filtered
        })
      }

      if (components.value.length) {
        result.push({
          id: 'components',
          label: 'Components',
          icon: 'bi-box',
          items: components.value,
          ignoreFilter: true,
        })
      }

      if (rules.value.length) {
        result.push({
          id: 'requirements',
          label: 'Requirements',
          icon: 'bi-shield-check',
          items: rules.value,
          ignoreFilter: true,
        })
      }
    }

    return result
  })

  // Reset function
  function reset() {
    projects.value = []
    components.value = []
    rules.value = []
    error.value = null
  }

  return {
    loading,
    error,
    groups,
    reset,
  }
}
```

---

## Configuration

### Quick Actions

Static items that are always available and filtered client-side.

```typescript
// config/command-palette.config.ts
import type { CommandPaletteItem } from '@/types/command-palette'

export const QUICK_ACTIONS: CommandPaletteItem[] = [
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
]
```

---

## Extensibility

### Adding New Searchable Content

To add a new searchable entity (e.g., Users, Settings, Admin areas):

#### 1. Add to Backend API

```ruby
# app/controllers/api/search_controller.rb
def global
  # ... existing code ...

  render json: {
    projects: search_projects(query, limit),
    components: search_components(query, limit),
    rules: search_rules(query, limit),
    users: search_users(query, limit),        # NEW
    settings: search_settings(query, limit),  # NEW
  }
end

private

def search_users(query, limit)
  return [] unless current_user&.admin?  # Permission check

  User.where('name ILIKE :q OR email ILIKE :q', q: "%#{query}%")
      .limit(limit)
      .map { |u| { id: u.id, name: u.name, email: u.email } }
end
```

#### 2. Add to useGlobalSearch.ts

```typescript
// In useGlobalSearch.ts

const users = ref<CommandPaletteItem[]>([])

// In fetchResults:
users.value = (data.users || []).map((u: any) => ({
  id: `user-${u.id}`,
  label: u.name,
  description: u.email,
  icon: 'bi-person',
  to: `/users/${u.id}`,
  onSelect: () => router.push(`/users/${u.id}`),
}))

// In groups computed:
if (users.value.length) {
  result.push({
    id: 'users',
    label: 'Users',
    icon: 'bi-people',
    items: users.value,
    ignoreFilter: true,
  })
}
```

#### 3. Add Quick Actions

```typescript
// In command-palette.config.ts

export const ADMIN_ACTIONS: CommandPaletteItem[] = [
  {
    id: 'manage-users',
    label: 'Manage Users',
    description: 'User administration',
    icon: 'bi-people',
    to: '/admin/users',
  },
  {
    id: 'system-settings',
    label: 'System Settings',
    description: 'Configure Vulcan',
    icon: 'bi-gear',
    to: '/admin/settings',
  },
]

// Conditionally include based on user role
export function getQuickActions(isAdmin: boolean): CommandPaletteItem[] {
  const actions = [...QUICK_ACTIONS]
  if (isAdmin) {
    actions.push(...ADMIN_ACTIONS)
  }
  return actions
}
```

### Adding Context-Specific Actions

For actions that depend on current page context:

```typescript
// In useGlobalSearch.ts

export function useGlobalSearch(
  searchTerm: Ref<string>,
  context?: { componentId?: number; projectId?: number }
) {
  // ... existing code ...

  const contextActions = computed<CommandPaletteItem[]>(() => {
    const actions: CommandPaletteItem[] = []

    if (context?.componentId) {
      actions.push({
        id: 'export-component',
        label: 'Export Component',
        description: 'Export as XCCDF or InSpec',
        icon: 'bi-download',
        onSelect: () => exportComponent(context.componentId),
      })
    }

    return actions
  })

  // Include in groups...
}
```

---

## Reka UI Components Used

From `reka-ui`:

| Component | Purpose |
|-----------|---------|
| `DialogRoot` | Modal container |
| `DialogPortal` | Portal for overlay |
| `DialogOverlay` | Backdrop |
| `DialogContent` | Modal content |
| `DialogTitle` | Accessibility title (VisuallyHidden) |
| `DialogDescription` | Accessibility description |
| `VisuallyHidden` | Hide from visual but keep for screen readers |
| `ListboxRoot` | Listbox container with selection |
| `ListboxFilter` | Search input that filters items |
| `ListboxContent` | Scrollable content area |
| `ListboxGroup` | Group container |
| `ListboxGroupLabel` | Group header |
| `ListboxItem` | Selectable item |

---

## Keyboard Navigation

| Key | Action |
|-----|--------|
| `Cmd+J` / `Ctrl+J` | Open command palette |
| `Escape` | Close |
| `↑` / `↓` | Navigate items |
| `Enter` | Select item |
| `Backspace` (empty) | Navigate back (if nested) |

---

## Styling (Bootstrap 5)

```scss
// In application.scss or component scoped styles

.command-palette-overlay {
  position: fixed;
  inset: 0;
  z-index: 1050;
  background-color: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(2px);
}

.command-palette-dialog {
  position: fixed;
  top: 15%;
  left: 50%;
  transform: translateX(-50%);
  z-index: 1051;
  width: 100%;
  max-width: 600px;
  max-height: 70vh;
  background-color: var(--bs-body-bg);
  border: 1px solid var(--bs-border-color);
  border-radius: var(--bs-border-radius-lg);
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
  overflow: hidden;
}

.command-palette-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--bs-border-color);
}

.command-palette-input {
  flex: 1;
  border: none;
  background: transparent;
  outline: none;
  font-size: 1rem;
}

.command-palette-content {
  max-height: calc(70vh - 120px);
  overflow-y: auto;
  padding: 0.5rem;
}

.command-palette-group-label {
  padding: 0.5rem 0.75rem;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  color: var(--bs-secondary-color);
}

.command-palette-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 0.75rem;
  border-radius: var(--bs-border-radius);
  cursor: pointer;
}

.command-palette-item[data-highlighted] {
  background-color: var(--bs-primary-bg-subtle);
}

.command-palette-item-label {
  font-weight: 500;
}

.command-palette-item-desc {
  font-size: 0.875rem;
  color: var(--bs-secondary-color);
}

.command-palette-empty {
  padding: 2rem;
  text-align: center;
  color: var(--bs-secondary-color);
}

.command-palette-footer {
  display: flex;
  gap: 1rem;
  padding: 0.5rem 1rem;
  border-top: 1px solid var(--bs-border-color);
  background-color: var(--bs-secondary-bg);
  font-size: 0.75rem;
  color: var(--bs-secondary-color);
}
```

---

## Implementation Checklist

- [ ] Create `types/command-palette.ts`
- [ ] Create `config/command-palette.config.ts`
- [ ] Create `composables/useCommandPalette.ts`
- [ ] Update `composables/useGlobalSearch.ts`
- [ ] Rewrite `components/shared/CommandPalette.vue` using Listbox
- [ ] Test Quick Actions filtering (Fuse.js)
- [ ] Test API search (ignoreFilter: true)
- [ ] Test keyboard navigation
- [ ] Test empty states
- [ ] Add accessibility labels

---

## Future Enhancements

1. **Recent Items** - Track and display recently selected items
2. **Nested Navigation** - Children items with back navigation
3. **Keyboard Shortcuts Display** - Show kbds for actions
4. **Highlighting** - Highlight matched text in results
5. **Virtual Scrolling** - For large result sets
6. **Context Awareness** - Different actions based on current page

---

*Document created: Session 20, 2025-11-29*
*Based on Nuxt UI v4 CommandPalette patterns*
