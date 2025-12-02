# Page Architecture

This document describes the Vue 3 page architecture patterns used in Vulcan's SPA.

## Overview

Vulcan uses Vue 3's **Suspense** feature for async data loading, combined with:
- **ErrorBoundary** for error handling
- **PageContainer** for consistent layout
- **Async setup** pattern for data fetching

## Core Components

### App.vue - The Layout Shell

```vue
<main class="flex-grow-1 overflow-auto pb-5">
  <RouterView v-slot="{ Component }">
    <template v-if="Component">
      <ErrorBoundary>
        <Suspense>
          <component :is="Component" />
          <template #fallback>
            <PageContainer>
              <PageSpinner message="Loading..." />
            </PageContainer>
          </template>
        </Suspense>
      </ErrorBoundary>
    </template>
  </RouterView>
</main>
```

**How it works:**
1. `RouterView` renders the matched page component
2. `ErrorBoundary` catches any errors thrown during async setup
3. `Suspense` shows the fallback spinner while async setup completes
4. Once resolved, the page component renders

### ErrorBoundary.vue

Catches errors from async child components using `onErrorCaptured`.

**Location:** `components/shared/ErrorBoundary.vue`

**Features:**
- Displays error message with Bootstrap alert styling
- Provides "Try Again" button to retry
- Logs errors to console for debugging

### PageSpinner.vue

Loading indicator for Suspense fallback.

**Location:** `components/shared/PageSpinner.vue`

**Props:**
- `message?: string` - Loading message (default: "Loading...")

### PageContainer.vue

Standard page layout container for consistent alignment.

**Location:** `components/shared/PageContainer.vue`

**Props:**
- `fluid?: boolean` - Remove max-width constraint
- `noPadding?: boolean` - Remove vertical padding

## Page Patterns

### Standard Page (with data fetching)

```vue
<script setup lang="ts">
/**
 * Page description
 *
 * Uses async setup with Suspense for loading state.
 */
import PageContainer from '@/components/shared/PageContainer.vue'
import { useMyComposable } from '@/composables'

// Top-level await makes this component suspensible
const { data, refresh } = useMyComposable()
await refresh()

// Throw error if data not found - ErrorBoundary will catch it
if (!data) {
  throw new Error('Data not found')
}
</script>

<template>
  <PageContainer>
    <MyComponent :data="data" />
  </PageContainer>
</template>
```

### Index Page Pattern

```vue
<script setup lang="ts">
import { storeToRefs } from 'pinia'
import PageContainer from '@/components/shared/PageContainer.vue'
import { useItems } from '@/composables'
import { useAuthStore } from '@/stores'

const { items, refresh } = useItems()
const authStore = useAuthStore()
const { isAdmin } = storeToRefs(authStore)

// Top-level await
await refresh()
</script>

<template>
  <PageContainer>
    <ItemList :items="items" :is-admin="isAdmin" @refresh="refresh" />
  </PageContainer>
</template>
```

### Show Page Pattern

```vue
<script setup lang="ts">
import { useRoute } from 'vue-router'
import PageContainer from '@/components/shared/PageContainer.vue'
import { useItems } from '@/composables'

const route = useRoute()
const { fetchById } = useItems()

// Top-level await
const id = Number(route.params.id)
const item = await fetchById(id)

if (!item) {
  throw new Error('Item not found')
}
</script>

<template>
  <PageContainer>
    <ItemViewer :item="item" />
  </PageContainer>
</template>
```

### Form Page Pattern (no async)

Form pages that don't fetch data don't need async setup:

```vue
<script setup lang="ts">
import PageContainer from '@/components/shared/PageContainer.vue'
import MyForm from '@/components/MyForm.vue'
</script>

<template>
  <PageContainer>
    <MyForm />
  </PageContainer>
</template>
```

### Full-Width Page Pattern

For pages that need edge-to-edge backgrounds (like ControlsPage):

```vue
<script setup lang="ts">
// ... async setup ...
</script>

<template>
  <div class="my-page d-flex flex-column h-100">
    <!-- Header with full-width background -->
    <div class="border-bottom bg-body-secondary">
      <div class="container-fluid container-app py-2">
        <!-- Header content aligned with navbar -->
      </div>
    </div>

    <!-- Content area -->
    <div class="flex-grow-1 overflow-hidden">
      <div class="container-fluid container-app h-100">
        <!-- Content aligned with navbar -->
      </div>
    </div>
  </div>
</template>
```

**Note:** Don't use `PageContainer` for full-width pages. Instead, manage containers manually to allow full-width backgrounds while keeping content aligned.

## Key Concepts

### Why Suspense?

Before Suspense, every page repeated this pattern:

```vue
<script setup>
const loading = ref(true)
const error = ref(null)
const data = ref(null)

onMounted(async () => {
  try {
    data.value = await fetchData()
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div v-if="loading">spinner...</div>
  <div v-else-if="error">{{ error }}</div>
  <Content v-else :data="data" />
</template>
```

With Suspense, this becomes:

```vue
<script setup>
const data = await fetchData()
</script>

<template>
  <Content :data="data" />
</template>
```

**Benefits:**
- DRY - Loading/error handling is centralized in App.vue
- Cleaner templates - No v-if/v-else chains
- Consistent UX - Same loading spinner everywhere
- Less boilerplate - ~30-45% less code per page

### Error Handling

Errors thrown during async setup are caught by ErrorBoundary:

```vue
// This error will be caught and displayed by ErrorBoundary
if (!data) {
  throw new Error('Data not found')
}
```

The ErrorBoundary displays:
- Error message
- "Try Again" button (resets error state)
- Console logs for debugging

### Layout Alignment

All pages should use one of these patterns:

1. **PageContainer** - For standard pages with content aligned to navbar
2. **Manual containers** - For full-width backgrounds with aligned content

The `container-app` class provides max-width constraint (1600px) matching the navbar.

## File Structure

```
pages/
├── auth/
│   └── LoginPage.vue          # Form page, no async
├── components/
│   ├── ControlsPage.vue       # Full-width, async setup
│   ├── IndexPage.vue          # Standard index, async setup
│   └── ShowPage.vue           # Standard show, async setup
├── projects/
│   ├── IndexPage.vue          # Standard index, async setup
│   ├── NewPage.vue            # Form page, no async
│   └── ShowPage.vue           # Standard show, async setup
├── rules/
│   └── EditPage.vue           # TODO: implement with async
├── srgs/
│   ├── IndexPage.vue          # Standard index, async setup
│   └── ShowPage.vue           # Standard show, async setup
├── stigs/
│   ├── IndexPage.vue          # Standard index, async setup
│   └── ShowPage.vue           # Standard show, async setup
└── users/
    └── IndexPage.vue          # Standard index, async setup
```

## Migration Checklist

When creating or migrating a page:

- [ ] Add JSDoc comment describing the page
- [ ] Import `PageContainer` (or manage containers manually for full-width)
- [ ] Use top-level `await` for data fetching
- [ ] Throw errors for "not found" cases
- [ ] Remove loading/error refs and v-if chains
- [ ] Remove `onMounted` async wrapper
- [ ] Test loading state (spinner shows)
- [ ] Test error state (ErrorBoundary catches)
- [ ] Verify layout alignment with navbar/footer
