# Vulcan SPA - Pinia State Management Architecture

This document describes the Pinia store architecture for the Vulcan Vue 3 SPA.

## Overview

Vulcan uses [Pinia](https://pinia.vuejs.org/) for state management, following the **Options API pattern** for consistency across all stores. Each domain has its own store, API layer, and TypeScript interfaces.

## Directory Structure

```
app/javascript/
├── apis/                    # API layer (axios calls)
│   ├── auth.api.ts
│   ├── users.api.ts
│   ├── projects.api.ts
│   ├── components.api.ts
│   ├── srgs.api.ts
│   └── stigs.api.ts
├── stores/                  # Pinia stores
│   ├── index.ts             # Pinia instance + exports
│   ├── auth.store.ts
│   ├── users.store.ts
│   ├── projects.store.ts
│   ├── components.store.ts
│   ├── srgs.store.ts
│   ├── stigs.store.ts
│   └── toast.ts
├── types/                   # TypeScript interfaces
│   ├── index.ts             # Re-exports all types
│   ├── user.ts
│   ├── project.ts
│   ├── component.ts
│   ├── rule.ts
│   ├── srg.ts
│   ├── stig.ts
│   ├── membership.ts
│   └── access-request.ts
└── services/
    └── http.service.ts      # Axios instance with interceptors
```

## Store Pattern

All stores follow the Options API pattern:

```typescript
import { defineStore } from 'pinia'
import { getItems, createItem } from '@/apis/items.api'
import type { IItem, IItemsState } from '@/types'

const initialState: IItemsState = {
  items: [],
  currentItem: null,
  loading: false,
  error: null
}

export const useItemsStore = defineStore('items.store', {
  state: (): IItemsState => ({ ...initialState }),

  getters: {
    itemCount: (state) => state.items.length,
    getItemById: (state) => (id: number) => state.items.find(i => i.id === id)
  },

  actions: {
    // Initialize from Rails server-rendered data
    initFromWindowData() {
      const windowData = (window as any).vueAppData
      if (windowData?.items) {
        this.items = windowData.items
      }
    },

    // Fetch from API
    async fetchItems() {
      this.loading = true
      this.error = null
      try {
        const response = await getItems()
        this.items = response.data
        return response
      } catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to fetch items'
        throw error
      } finally {
        this.loading = false
      }
    },

    // Reset store
    reset() {
      Object.assign(this, initialState)
    }
  }
})
```

## Stores Reference

### auth.store.ts
**Purpose:** Current user authentication state

| Property | Type | Description |
|----------|------|-------------|
| `user` | `IUser \| null` | Current logged-in user |
| `loading` | `boolean` | Loading state |

| Getter | Returns | Description |
|--------|---------|-------------|
| `signedIn` | `boolean` | Whether user is logged in |
| `isAdmin` | `boolean` | Whether user is admin |
| `userEmail` | `string` | User's email |
| `userName` | `string` | User's name |
| `userId` | `number` | User's ID |

| Action | Parameters | Description |
|--------|------------|-------------|
| `setUser` | `userData: IUser` | Set current user |
| `clearUser` | - | Clear user and localStorage |
| `initFromWindowData` | - | Load from `window.vueAppData.currentUser` |
| `login` | `credentials: IUserLogin` | Login with email/password |
| `logout` | - | Logout and redirect |
| `register` | `userData: IUserRegister` | Register new user |

### users.store.ts
**Purpose:** Admin user management (list all users, promote/demote)

| Property | Type | Description |
|----------|------|-------------|
| `users` | `IUser[]` | All users (admin view) |
| `histories` | `IUserHistory[]` | Audit history |
| `loading` | `boolean` | Loading state |
| `error` | `string \| null` | Error message |

| Action | Parameters | Description |
|--------|------------|-------------|
| `initFromWindowData` | - | Load from `window.vueAppData` |
| `fetchUsers` | - | GET /users |
| `updateUser` | `id, data` | PATCH /users/:id |
| `deleteUser` | `id` | DELETE /users/:id |

### projects.store.ts
**Purpose:** Projects list and CRUD

| Property | Type | Description |
|----------|------|-------------|
| `projects` | `IProject[]` | User's available projects |
| `currentProject` | `IProject \| null` | Currently viewed project |
| `loading` | `boolean` | Loading state |
| `error` | `string \| null` | Error message |

| Getter | Returns | Description |
|--------|---------|-------------|
| `projectCount` | `number` | Total projects |
| `getProjectById` | `(id) => IProject` | Find project by ID |
| `memberProjects` | `IProject[]` | Projects user is member of |
| `adminProjects` | `IProject[]` | Projects user is admin of |

| Action | Parameters | Description |
|--------|------------|-------------|
| `initFromWindowData` | - | Load from `window.vueAppData.projects` |
| `fetchProjects` | - | GET /projects |
| `fetchProject` | `id` | GET /projects/:id |
| `createProject` | `data: IProjectCreate` | POST /projects |
| `updateProject` | `id, data` | PATCH /projects/:id |
| `deleteProject` | `id` | DELETE /projects/:id |

### components.store.ts
**Purpose:** Component management within projects

| Property | Type | Description |
|----------|------|-------------|
| `components` | `IComponent[]` | Components list |
| `currentComponent` | `IComponent \| null` | Currently viewed component |
| `loading` | `boolean` | Loading state |
| `error` | `string \| null` | Error message |

| Action | Parameters | Description |
|--------|------------|-------------|
| `setComponents` | `components[]` | Set components from project data |
| `fetchComponent` | `id` | GET /components/:id |
| `createComponent` | `data` | POST /components |
| `updateComponent` | `id, data` | PATCH /components/:id |
| `deleteComponent` | `id` | DELETE /components/:id |
| `duplicateComponent` | `id, options` | POST /components/:id/duplicate |

### srgs.store.ts
**Purpose:** Security Requirements Guides management

| Property | Type | Description |
|----------|------|-------------|
| `srgs` | `ISecurityRequirementsGuide[]` | All SRGs |
| `latestSrgs` | `ISrgListItem[]` | Latest version of each SRG |
| `currentSrg` | `ISecurityRequirementsGuide \| null` | Currently viewed SRG |

| Action | Parameters | Description |
|--------|------------|-------------|
| `fetchSrgs` | - | GET /security_requirements_guides |
| `fetchLatestSrgs` | - | GET /security_requirements_guides/latest |
| `fetchSrg` | `id` | GET /security_requirements_guides/:id |
| `uploadSrg` | `file: File` | POST /security_requirements_guides |
| `deleteSrg` | `id` | DELETE /security_requirements_guides/:id |

### stigs.store.ts
**Purpose:** STIGs management

| Property | Type | Description |
|----------|------|-------------|
| `stigs` | `IStig[]` | All STIGs |
| `currentStig` | `IStig \| null` | Currently viewed STIG |

| Action | Parameters | Description |
|--------|------------|-------------|
| `fetchStigs` | - | GET /stigs |
| `fetchStig` | `id` | GET /stigs/:id |
| `uploadStig` | `file: File` | POST /stigs |
| `deleteStig` | `id` | DELETE /stigs/:id |

### findReplace.store.ts
**Purpose:** Find & Replace operations within components
**Pattern:** Composition API (Setup syntax)
**Architecture:** See `docs-spa/FIND-REPLACE-ARCHITECTURE.md`

| Property | Type | Description |
|----------|------|-------------|
| `searchText` | `string` | Current search text |
| `replaceText` | `string` | Replacement text |
| `caseSensitive` | `boolean` | Case sensitivity flag |
| `selectedFields` | `string[]` | Fields to search |
| `matches` | `FlatMatch[]` | Flattened matches for navigation |
| `totalMatches` | `number` | Total match count |
| `totalRules` | `number` | Rules with matches |
| `currentIndex` | `number` | Current position in matches |
| `loop` | `boolean` | Wrap navigation at ends |
| `isSearching` | `boolean` | Search in progress |
| `isReplacing` | `boolean` | Replace in progress |
| `undoStack` | `UndoEntry[]` | Undo history |
| `isOpen` | `boolean` | Modal visibility |

| Getter | Returns | Description |
|--------|---------|-------------|
| `currentMatch` | `FlatMatch \| null` | Match at currentIndex |
| `hasNext` | `boolean` | Can navigate forward |
| `hasPrev` | `boolean` | Can navigate back |
| `progress` | `string` | "3 of 47" |
| `summary` | `string` | "47 matches in 12 rules" |
| `canUndo` | `boolean` | Has undo history |
| `hasResults` | `boolean` | Has matches |
| `isLoading` | `boolean` | Any operation in progress |

| Action | Parameters | Description |
|--------|------------|-------------|
| `search` | `componentId` | Find all matches |
| `nextMatch` | - | Navigate to next (no API) |
| `prevMatch` | - | Navigate to previous (no API) |
| `goToMatch` | `index` | Jump to specific match |
| `skip` | - | Alias for nextMatch |
| `replaceOne` | `componentId` | Replace current with replaceText |
| `replaceOneWithCustom` | `componentId, text` | Replace with custom text |
| `replaceAllMatches` | `componentId, comment?` | Replace all |
| `undoLast` | `componentId` | Undo last replace |
| `open` | - | Open modal |
| `close` | - | Close modal |
| `toggle` | - | Toggle modal |
| `reset` | - | Clear results |
| `resetAll` | - | Clear everything |

**Key Design:**
- Navigation is client-side (no API calls for next/prev)
- Backend is stateless (atomic operations only)
- Matches VS Code/Monaco Editor patterns

## Usage in Components

### Importing Stores

```typescript
import { useAuthStore, useProjectsStore } from '@/stores'

const authStore = useAuthStore()
const projectsStore = useProjectsStore()
```

### Accessing State (Reactive)

```typescript
// In template
{{ projectsStore.projects }}
{{ authStore.signedIn }}

// In script (reactive)
projectsStore.projects  // directly reactive in Options API stores
```

### Calling Actions

```typescript
// Initialize from server data
onMounted(() => {
  projectsStore.initFromWindowData()
})

// Fetch from API
await projectsStore.fetchProjects()

// CRUD operations
await projectsStore.createProject({ name: 'New Project', visibility: 'hidden' })
await projectsStore.updateProject(id, { name: 'Updated Name' })
await projectsStore.deleteProject(id)
```

### Handling Loading/Error States

```vue
<template>
  <div v-if="projectsStore.loading">Loading...</div>
  <div v-else-if="projectsStore.error" class="alert alert-danger">
    {{ projectsStore.error }}
  </div>
  <div v-else>
    <!-- Content -->
  </div>
</template>
```

## Data Flow

1. **Initial Page Load:**
   - Rails renders `window.vueAppData` with server data
   - Vue app mounts, stores call `initFromWindowData()`
   - Data is immediately available without API call

2. **Subsequent Navigation (SPA):**
   - Vue Router handles navigation
   - Stores fetch data via API if not cached
   - Loading states shown during fetch

3. **User Actions:**
   - Component calls store action
   - Store makes API call, updates local state
   - Vue reactivity updates all consuming components

## API Layer

Each API file exports functions that wrap axios calls:

```typescript
// apis/projects.api.ts
import { http } from '@/services/http.service'
import type { IProject, IProjectCreate } from '@/types'

export const getProjects = () => http.get<IProject[]>('/projects')
export const createProject = (data: IProjectCreate) =>
  http.post('/projects', { project: data })
```

### HTTP Service Features

- Base URL: `/`
- Headers: `Content-Type: application/json`, `Accept: application/json`
- CSRF token automatically added from meta tag
- Error interceptor normalizes error messages

## TypeScript Types

All types are defined in `app/javascript/types/` and re-exported from `index.ts`:

```typescript
import type { IUser, IProject, IComponent, IRule } from '@/types'
```

See individual type files for complete interface definitions.

## Best Practices

1. **Always use stores for shared state** - Don't use `window.vueAppData` directly in components
2. **Initialize on mount** - Call `initFromWindowData()` in component's `onMounted`
3. **Handle loading/error states** - Show appropriate UI for async operations
4. **Use getters for derived data** - Don't compute in components
5. **Keep actions focused** - One action = one API call + state update
