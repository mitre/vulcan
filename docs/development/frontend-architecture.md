# Frontend Architecture

Vulcan's frontend follows a four-layer architecture inspired by GitLab's Vue patterns and hexagonal architecture principles. The layers enforce strict downward dependencies — each layer may only call the layer below it, never above.

This architecture is designed to survive three major transitions without rewrites:
1. **Vue 2.7 → Vue 3** — composables and stores carry over unchanged
2. **22 Vue instances → 1 SPA** — stores become route-scoped, API layer unchanged
3. **DB 3NF normalization** — only the API response normalizer changes, stores and components stay stable

## The Four Layers

```
┌─────────────────────────────────────────────────┐
│  4. PRESENTATION                                │
│     Presentational components — props in,        │
│     events out. Zero store/API access.           │
│     app/javascript/components/shared/            │
├─────────────────────────────────────────────────┤
│  3. CONTAINER / PAGE                            │
│     Orchestration — connects stores to UI.       │
│     The ONLY layer that touches stores.          │
│     app/javascript/components/*/Page.vue         │
│     app/javascript/components/*/Container.vue    │
├─────────────────────────────────────────────────┤
│  2. STATE + LOGIC                               │
│     Pinia stores — centralized state + cache.    │
│     Composables — shared stateful logic.         │
│     app/javascript/stores/                       │
│     app/javascript/composables/                  │
├─────────────────────────────────────────────────┤
│  1. API / DATA ACCESS                           │
│     HTTP client wrappers — pure fetch calls.     │
│     No state, no business logic.                 │
│     app/javascript/api/                          │
└─────────────────────────────────────────────────┘
```

## Layer Rules

### Layer 1: API (`app/javascript/api/`)

**What it does:** Pure HTTP calls. Send request, return response. That's it.

**Rules:**
- One file per Rails resource (`reviewsApi.js`, `componentsApi.js`, `usersApi.js`)
- Functions accept plain JS objects, return Promises of API responses
- NO state management, NO caching, NO business logic
- NO imports from stores, composables, or components
- Response shape matches the Rails controller JSON output exactly

**What goes here:**
```javascript
// api/reviewsApi.js
export function getReviewResponses(reviewId) {
  return api.get(`/reviews/${reviewId}/responses`);
}
export function triageReview(reviewId, payload) {
  return api.patch(`/reviews/${reviewId}/triage`, { review: payload });
}
```

**What does NOT go here:** Caching, retry logic, optimistic updates, state mutation, error classification beyond HTTP status.

### Layer 2: State + Logic (`stores/` + `composables/`)

**What it does:** Centralized reactive state (Pinia stores) and reusable stateful logic (composables). The brain of the frontend.

#### Stores (`app/javascript/stores/`)

**Rules:**
- Setup Store pattern only (`defineStore('id', () => { ... })`)
- One store per domain: `useCommentsStore`, `useTriageStore`, `usePreferencesStore`
- Stores call Layer 1 (API) to fetch/mutate data
- Stores normalize API responses before storing (isolates DB schema changes)
- Stores may call other stores inside actions/getters (never at setup root)
- NO rendering logic, NO DOM access, NO component imports
- Stores are the **single source of truth** — components never cache API data locally

**Normalization example — isolates DB schema changes:**
```javascript
// Store normalizes API response to a stable shape.
// When the DB gets 3NF'd and the API response changes,
// ONLY this normalizer changes — stores, composables,
// and components stay the same.
function normalizeComment(raw) {
  return {
    id: raw.id,
    authorName: raw.author_name || raw.commenter_display_name,
    authorEmail: raw.commenter_email,
    text: raw.comment,
    section: raw.section,
    triageStatus: raw.triage_status,
    createdAt: raw.created_at,
    reactions: raw.reactions || {},
    responsesCount: raw.responses_count || 0,
    isImported: raw.commenter_imported || false,
  };
}
```

#### Composables (`app/javascript/composables/`)

**Rules:**
- Named `useXxx()` — always a function, always returns an object
- Encapsulate shared **stateful** logic (not just formatting — use utils for that)
- May use stores (import `useStore()` and call inside the composable)
- May use Vue lifecycle hooks (`onMounted`, `onUnmounted`, `watch`)
- Return `ref`s and functions — consumers destructure what they need
- Replace mixins for all new code (existing mixins freeze, migrate incrementally)

**When to use a composable vs a store:**

| Composable | Store |
|---|---|
| Component-scoped lifecycle | App-scoped lifecycle |
| Logic without persistent state | Persistent state + cache |
| Multiple instances (each component gets its own) | Singleton (shared across components) |
| UI behavior (toggle, scroll, keyboard) | Data management (fetch, cache, mutate) |

**Example — composable uses store:**
```javascript
// composables/useCommentReactions.js
import { ref } from "vue";
import { useCommentsStore } from "../stores/comments";
import { toggleReaction } from "../api/reviewsApi";

export function useCommentReactions() {
  const pending = ref(new Set());

  async function toggle(reviewId, kind, currentReactions, apply) {
    if (pending.value.has(`${reviewId}:${kind}`)) return;
    pending.value.add(`${reviewId}:${kind}`);
    const prev = { ...currentReactions };

    // Optimistic update
    apply(optimisticUpdate(currentReactions, kind));

    try {
      const { data } = await toggleReaction(reviewId, kind);
      apply(data.reactions);
    } catch {
      apply(prev);
    } finally {
      pending.value.delete(`${reviewId}:${kind}`);
    }
  }

  return { toggle, pending };
}
```

### Layer 3: Container / Page Components

**What it does:** Orchestrates data flow between stores and presentational components. The only layer that calls `useStore()` or composables.

**Rules:**
- Container components wire stores to presentational components via props
- Container components handle events from presentational components and dispatch store actions
- Containers may use composables
- Containers do NOT render complex UI — they delegate to Layer 4
- In Vulcan v2.x: Page components (e.g., `ComponentTriagePage.vue`, `ProjectTriagePage.vue`) serve as containers

**Pattern:**
```javascript
// Container wires store to presentational component
export default {
  setup() {
    const store = useCommentsStore();
    const { loading, error } = storeToRefs(store);
    const { fetchComments } = store;

    const { toggle } = useCommentReactions();

    return { loading, error, fetchComments, toggle };
  },
  // Template renders presentational components with props
};
```

### Layer 4: Presentational Components

**What it does:** Pure rendering. Receives data via props, emits events. Zero knowledge of stores, API, or data fetching.

**Rules:**
- ALL data comes via props or provide/inject
- ALL mutations go UP via `$emit` events
- NO imports from `stores/` or `api/`
- NO `useStore()` calls
- Lives in `components/shared/` when reusable, or alongside its container

**Example — CommentItem is purely presentational:**
```vue
<template>
  <b-media>
    <template #aside>
      <UserBadge :name="comment.authorName" :email="comment.authorEmail" />
    </template>
    <slot name="header">
      <CommentAuthorLine :name="comment.authorName" />
      <SectionLabel v-if="comment.section" :section="comment.section" />
    </slot>
    <slot name="body">
      <p class="mb-1 white-space-pre-wrap">{{ comment.text }}</p>
    </slot>
    <slot name="actions">
      <CommentActions
        :review-id="comment.id"
        :reactions="comment.reactions"
        :responses-count="comment.responsesCount"
        @toggle-reaction="$emit('toggle-reaction', $event)"
        @reply="$emit('reply', $event)"
      />
    </slot>
    <slot name="extra" />
  </b-media>
</template>

<script>
export default {
  name: "CommentItem",
  props: {
    comment: { type: Object, required: true },
  },
};
</script>
```

---

## Dependency Direction

```
Component ──→ Composable ──→ Store ──→ API ──→ Rails
    │              │            │
    │              │            └── normalizes response
    │              └── may use store
    └── receives via props (never imports store directly)
         UNLESS it's a Container/Page component
```

**Forbidden dependencies:**
- API → Store (API is stateless)
- API → Component (API doesn't know about Vue)
- Presentational Component → Store (only Containers may)
- Store → Component (stores don't render)
- Composable → Component (composables don't render)

---

## How This Survives Future Transitions

### Vue 3 Migration

| Layer | Impact |
|---|---|
| API | Zero change — pure JS, no Vue dependency |
| Stores | Zero change — Pinia 2 Setup Stores = Pinia 3 Setup Stores |
| Composables | Zero change — Composition API is identical in Vue 3 |
| Components | Template syntax changes, `v-model` changes, slot syntax stable |

The only migration work is in components (template compiler differences). All state management and logic layers carry over unchanged.

### Single SPA Consolidation (22 → 1)

| Layer | Impact |
|---|---|
| API | Zero change |
| Stores | Remove per-page `createPinia()` → one global pinia instance + Vue Router |
| Composables | Zero change |
| Components | Page components become route views, add `<router-view>` |
| Pack files | Eliminated — one entry point |

The `createVulcanApp()` helper becomes unnecessary. Stores survive because they're already independent modules.

### DB 3NF Normalization

| Layer | Impact |
|---|---|
| API | Response shapes may change (Rails controller/Blueprint changes) |
| Stores | **Normalizer functions absorb the change** — store consumers see the same shape |
| Composables | Zero change (consume normalized store state) |
| Components | Zero change (receive via props) |

This is the critical win. When the DB goes from `reviews.author_name` (denormalized) to a join through `users`, the API response changes but the store normalizer maps it to the same `{ authorName, authorEmail }` shape. Every composable and component is unaffected.

---

## File Organization

```
app/javascript/
├── api/                        # Layer 1: Pure HTTP calls
│   ├── baseApi.js              # Shared HTTP client (interceptors, CSRF)
│   ├── componentsApi.js        # Component endpoints
│   ├── reviewsApi.js           # Review/comment endpoints
│   └── usersApi.js             # User endpoints
├── stores/                     # Layer 2a: Pinia stores
│   ├── comments.js             # useCommentsStore
│   └── triage.js               # useTriageStore (future)
├── composables/                # Layer 2b: Shared stateful logic
│   ├── useCommentReactions.js  # Optimistic reaction toggle
│   ├── useCommentThread.js     # Thread expand/collapse/fetch
│   └── useDateFormat.js        # Date formatting (replaces DateFormatMixin)
├── lib/                        # Utilities and helpers
│   └── createVulcanApp.js      # Vue instance factory
├── components/
│   ├── shared/                 # Layer 4: Presentational (reusable)
│   │   ├── CommentItem.vue     # Single comment rendering
│   │   ├── CommentActions.vue  # Reactions + thread (bundled)
│   │   ├── CommentBody.vue     # Comment text + metadata
│   │   ├── UserBadge.vue       # Avatar + popover
│   │   └── SectionLabel.vue    # Rule section badge
│   ├── components/             # Layer 3+4: Container + presentational
│   │   ├── ComponentTriagePage.vue  # Container (uses stores)
│   │   └── CommentDedupBanner.vue   # Uses CommentItem via slots
│   └── triage/                 # Layer 3+4: Triage workspace
│       ├── TriageSplitView.vue # Container (uses stores)
│       └── CommentTriageForm.vue    # Presentational (props only)
├── mixins/                     # LEGACY — freeze, migrate to composables
└── packs/                      # Entry points (use createVulcanApp)
```

## Migration Strategy (Current → Target)

**Phase 1 (NOW):** Install Pinia, create `createVulcanApp`, define `useCommentsStore` skeleton. Pilot with 2 pack files.

**Phase 2:** Build composables (`useCommentReactions`, `useCommentThread`) that replace mixins for comment components. Store fetches + caches comments.

**Phase 3:** Build compound presentational components (`CommentItem`, `CommentBody`, `CommentActions`). These are Layer 4 — pure props, zero store access.

**Phase 4:** Migrate container components to use store + composables + presentational components. Remove mixin imports. Each migration is one component at a time.

**Phase 5 (future):** When Vue 3 / SPA / 3NF happens, only the affected layer changes. The architecture absorbs it.
