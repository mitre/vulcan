# State Management & Composables

Vulcan uses **Pinia 2.x** for centralized state management with **Vue 2.7**'s built-in Composition API. No `@vue/composition-api` package needed — Vue 2.7 includes `ref`, `computed`, `watch`, `setup()` natively.

This guide covers store patterns, composables, testing, plugins, and integration with Vulcan's 22 separate Vue instances.

## Quick Rules

1. **Setup Stores only** — `defineStore('id', () => { ... })`, never Options Stores
2. **One store per domain** — `useCommentsStore`, `useTriageStore`, not one god-store
3. **Options API consumers use `mapState`/`mapActions`** — incremental adoption, no rewrites
4. **`createVulcanApp()` for all Vue instances** — installs Pinia + BootstrapVue + plugins
5. **HMR in every store file** — `acceptHMRUpdate` at the bottom
6. **Tests use `setActivePinia(createPinia())`** — fresh store per test
7. **Composables replace mixins** for new shared logic — testable, explicit dependencies
8. **Store actions own API calls** — components read state, never call APIs directly

---

## Architecture: 22 Vue Instances

Vulcan has 22 separate Vue instances (one per page/pack file). All share ONE `createPinia()` instance via `createVulcanApp()` (Pinia creator's documented pattern for multi-app). On `turbolinks:before-visit`, all stores are reset via `$reset()` to prevent stale cache from the previous page.

```
Pack file  ──→  createVulcanApp()  ──→  new Vue({ pinia: createPinia() })
                     │
                     ├── Vue.use(PiniaVuePlugin)     (once globally)
                     ├── Vue.use(BootstrapVue)
                     ├── Vue.use(IconsPlugin)
                     └── Vue.use(TurbolinksAdapter)
```

Packs that don't use stores still get Pinia installed — zero overhead (stores instantiate lazily on first `useStore()` call).

---

## Defining Stores

### Setup Store (REQUIRED pattern)

```javascript
// app/javascript/stores/comments.js
import { ref, computed } from "vue";
import { defineStore, acceptHMRUpdate } from "pinia";
import { getComments } from "../api/componentsApi";

export const useCommentsStore = defineStore("comments", () => {
  // ── State (ref) ──────────────────────────────
  const cache = ref({});
  const loading = ref(false);
  const error = ref(null);

  // ── Getters (computed) ───────────────────────
  const commentCount = computed(() =>
    Object.values(cache.value).reduce(
      (sum, v) => sum + (v.rows?.length || 0),
      0,
    ),
  );

  // ── Actions (functions) ──────────────────────
  async function fetchComments(componentId, params) {
    const key = cacheKey(componentId, params);
    if (cache.value[key]) return cache.value[key];

    loading.value = true;
    error.value = null;
    try {
      const { data } = await getComments(componentId, params);
      cache.value[key] = data;
      return data;
    } catch (err) {
      error.value = err;
      throw err;
    } finally {
      loading.value = false;
    }
  }

  function invalidateCache(componentId) {
    Object.keys(cache.value)
      .filter((k) => k.startsWith(`${componentId}:`))
      .forEach((k) => delete cache.value[k]);
  }

  // ── Private helpers (not returned, closure-scoped) ──
  function cacheKey(id, params) {
    return `${id}:${JSON.stringify(params || {})}`;
  }

  // ── $reset (manual for Setup Stores) ─────────
  function $reset() {
    cache.value = {};
    loading.value = false;
    error.value = null;
  }

  return {
    cache, loading, error,
    commentCount,
    fetchComments, invalidateCache, $reset,
  };
});

// HMR — ALWAYS add this at the bottom of every store file
if (import.meta.hot) {
  import.meta.hot.accept(acceptHMRUpdate(useCommentsStore, import.meta.hot));
}
```

### Why Setup Stores, not Options Stores

| Setup Store | Options Store |
|---|---|
| Uses `ref`, `computed`, functions — same as Composition API | Uses `state()`, `getters`, `actions` — separate syntax |
| Can use any composable inside the store | Limited composable support in `state()` |
| Matches v3.x architecture (future migration) | Would need rewriting for v3.x |
| Private helpers via closures (not returned) | Everything is public |
| `$reset()` must be defined manually | `$reset()` built-in |

---

## Using Stores in Components

### Composition API (`setup()` function) — MANDATORY: use `storeToRefs`

**`storeToRefs()` is REQUIRED when destructuring state/getters from a store in `setup()`.** Without it, destructured values silently lose reactivity — the component renders stale data with no error. This is the #1 Pinia gotcha.

```javascript
import { useCommentsStore } from "../../stores/comments";
import { storeToRefs } from "pinia";

export default {
  setup() {
    const store = useCommentsStore();
    // storeToRefs preserves reactivity for state/getters
    const { loading, error, commentCount } = storeToRefs(store);
    // actions destructure directly (no ref wrapper needed)
    const { fetchComments, invalidateCache } = store;

    return { loading, error, commentCount, fetchComments, invalidateCache };
  },
};
```

### Options API (`mapState`/`mapActions`)

For existing components — incremental adoption without rewriting:

```javascript
import { mapState, mapActions } from "pinia";
import { useCommentsStore } from "../../stores/comments";

export default {
  computed: {
    ...mapState(useCommentsStore, ["loading", "error", "commentCount"]),
    ...mapState(useCommentsStore, {
      isLoading: "loading",
      totalComments: (store) => store.commentCount,
    }),
  },
  methods: {
    ...mapActions(useCommentsStore, ["fetchComments", "invalidateCache"]),
  },
};
```

### Writable State (`mapWritableState`)

For form inputs bound directly to store state:

```javascript
import { mapWritableState } from "pinia";

export default {
  computed: {
    ...mapWritableState(useCommentsStore, ["filterSection"]),
  },
};
```

### Destructuring: `storeToRefs` Required

Direct destructuring breaks reactivity. Always use `storeToRefs()` for state and getters:

```javascript
// BAD — loses reactivity
const { loading, error } = store;

// GOOD — preserves reactivity
const { loading, error } = storeToRefs(store);

// Actions are fine to destructure directly
const { fetchComments } = store;
```

---

## Composing Stores

One store can use another inside **actions and getters** — never at the top level of the setup function (prevents circular dependencies).

```javascript
export const useTriageStore = defineStore("triage", () => {
  async function triageComment(reviewId, payload) {
    // Call inside the action, NOT at setup root
    const commentsStore = useCommentsStore();
    await triageReview(reviewId, payload);
    commentsStore.invalidateCache(componentId);
  }

  return { triageComment };
});
```

---

## Composables

Composables are functions that encapsulate reusable Composition API logic. They replace Vue 2 mixins with explicit imports and testable pure functions.

### When to Use Composables vs Stores vs Utils

| Use a Composable | Use a Store | Use a plain util (`lib/`) |
|---|---|---|
| Shared **stateful** logic (reactive refs, lifecycle hooks) | Centralized state shared across components | Pure functions with no state or reactivity |
| Component-scoped instances (each caller gets own state) | Singleton per pinia instance | Stateless — same output for same input |
| Example: `useCommentReactions` (pending ref) | Example: `useCommentsStore` (cache) | Example: `dateFormat.js` (string in, string out) |

**Rule of thumb:** If it uses `ref()`, `computed()`, or lifecycle hooks → composable.
If it's a pure function with no Vue reactivity → `lib/` utility, not a composable.
`useDateFormat` is technically a util wrapped in a composable factory — acceptable
during the mixin→composable migration, but pure utils should live in `lib/`.

### Composable Pattern

```javascript
// app/javascript/composables/useCommentReactions.js
import { ref } from "vue";
import { toggleReaction } from "../api/reviewsApi";

export function useCommentReactions() {
  const pendingReactions = ref(new Set());

  async function toggle(reviewId, kind, currentReactions, apply) {
    if (pendingReactions.value.has(`${reviewId}:${kind}`)) return;
    pendingReactions.value.add(`${reviewId}:${kind}`);

    const prev = { ...currentReactions };
    // Optimistic update
    const mine = currentReactions[kind]?.mine;
    apply({
      ...currentReactions,
      [kind]: {
        count: currentReactions[kind].count + (mine ? -1 : 1),
        mine: !mine,
      },
    });

    try {
      const { data } = await toggleReaction(reviewId, kind);
      apply(data.reactions);
    } catch {
      apply(prev); // Rollback on error
    } finally {
      pendingReactions.value.delete(`${reviewId}:${kind}`);
    }
  }

  return { toggle, pendingReactions };
}
```

### Using Composables in Stores

Setup Stores can use composables — properties are automatically classified:

```javascript
export const usePreferencesStore = defineStore("preferences", () => {
  const triageViewMode = useLocalStorage("vulcan-triage-view", "table");
  return { triageViewMode };
});
```

---

## Mutating State

### Direct Mutation

```javascript
store.count++;
```

### `$patch` (multiple changes, single devtools entry)

```javascript
// Object syntax
store.$patch({ count: store.count + 1, name: "New Name" });

// Function syntax (for arrays and complex mutations)
store.$patch((state) => {
  state.items.push({ name: "shoes" });
  state.hasChanged = true;
});
```

### Subscribing to State Changes

```javascript
store.$subscribe((mutation, state) => {
  // mutation.type: 'direct' | 'patch object' | 'patch function'
  localStorage.setItem("comments-cache", JSON.stringify(state));
});
```

### Subscribing to Actions

```javascript
store.$onAction(({ name, args, after, onError }) => {
  const start = Date.now();
  after(() => console.log(`${name} took ${Date.now() - start}ms`));
  onError((err) => console.warn(`${name} failed:`, err));
});
```

---

## Using Stores Outside Components

Pass the Pinia instance explicitly when there's no active component context:

```javascript
// In API interceptors, utilities, etc.
function handleCommentUpdate(pinia, componentId) {
  const store = useCommentsStore(pinia);
  store.invalidateCache(componentId);
}

// In Vue lifecycle hooks — access via this.$pinia
export default {
  mounted() {
    const store = useCommentsStore(this.$pinia);
  },
};
```

---

## Plugins

Plugins extend all stores. Use sparingly — only for cross-cutting concerns.

```javascript
function errorTrackingPlugin({ store }) {
  store.$onAction(({ name, onError }) => {
    onError((err) => {
      console.error(`[${store.$id}] Action ${name} failed:`, err);
    });
  });
}

const pinia = createPinia();
pinia.use(errorTrackingPlugin);
```

Plugin context: `{ pinia, app, store, options }`. Return an object to add properties to every store.

---

## Testing

### Unit Testing Stores (no component)

```javascript
import { setActivePinia, createPinia } from "pinia";
import { useCommentsStore } from "@/stores/comments";

describe("useCommentsStore", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("starts with empty cache", () => {
    const store = useCommentsStore();
    expect(store.cache).toEqual({});
  });
});
```

### Component Testing (`createTestingPinia`)

Install `@pinia/testing` as a devDependency:

```javascript
import { mount } from "@vue/test-utils";
import { createTestingPinia } from "@pinia/testing";

const wrapper = mount(MyComponent, {
  global: {
    plugins: [
      createTestingPinia({
        initialState: {
          comments: { loading: false, cache: {} },
        },
        stubActions: false,
      }),
    ],
  },
});
```

### Mocking Specific Actions

```javascript
import { vi } from "vitest";
const store = useCommentsStore();
vi.spyOn(store, "fetchComments").mockResolvedValue({
  rows: [],
  pagination: { total: 0 },
});
```

### Testing with Plugins

```javascript
const app = createApp({});
beforeEach(() => {
  const pinia = createPinia().use(somePlugin);
  app.use(pinia);
  setActivePinia(pinia);
});
```

---

## `createVulcanApp()` Helper

All pack files use this shared helper:

```javascript
// app/javascript/lib/createVulcanApp.js
import Vue from "vue";
import TurbolinksAdapter from "vue-turbolinks";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { PiniaVuePlugin, createPinia } from "pinia";
import { bvConfig } from "../config/bootstrapVueConfig";

Vue.use(PiniaVuePlugin);
Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue, bvConfig);
Vue.use(IconsPlugin);

export function createVulcanApp({ el, componentName, component, directives }) {
  if (component) Vue.component(componentName, component);
  if (directives) {
    Object.entries(directives).forEach(([name, dir]) => {
      Vue.directive(name, dir);
    });
  }

  document.addEventListener("turbolinks:load", () => {
    new Vue({ el, pinia: createPinia() });
  });
}
```

### Pack File Usage

```javascript
import { createVulcanApp } from "../lib/createVulcanApp";
import ComponentTriagePage from "../components/components/ComponentTriagePage.vue";
import linkify from "v-linkify";

createVulcanApp({
  el: "#componenttriage",
  componentName: "Componenttriage",
  component: ComponentTriagePage,
  directives: { linkified: linkify },
});
```

---

## File Organization

```
app/javascript/
├── stores/                     # Pinia stores (one per domain)
│   ├── comments.js             # Comment fetch/cache/triage state
│   ├── triage.js               # Triage workflow (future)
│   └── preferences.js          # User UI preferences (future)
├── composables/                # Composition API composables
│   ├── useCommentReactions.js  # Replaces ReactionToggleMixin
│   ├── useCommentThread.js     # Thread expand/collapse/fetch
│   └── useCommentTriage.js     # Triage form state + submit
├── lib/
│   └── createVulcanApp.js      # Shared Vue instance factory
├── mixins/                     # Legacy (freeze, migrate away)
│   ├── AlertMixin.vue          # → useAlert composable (future)
│   ├── ReactionToggleMixin.vue # → useCommentReactions
│   └── DateFormatMixin.vue     # → useDateFormat (future)
└── packs/                      # Entry points (use createVulcanApp)
```

---

## Verified Patterns (Do Not Change)

These patterns were verified by an 8-agent expert review (2026-06-04) and confirmed correct:

| Pattern | Why It's Correct | Do Not |
|---------|-----------------|--------|
| CSRF via ky `beforeRequest` hook | Reads meta tag per-request. FormMixin is backward-compat only — ky handles CSRF natively. | Remove FormMixin from components that also use direct ky calls (esbuild bundle isolation means each pack needs its own CSRF source) |
| `$reset()` on `turbolinks:before-visit` | Prevents stale cache leaking across page navigations. Required for all Setup Stores (Pinia does not auto-generate `$reset` for them). | Remove the reset listener or skip `$reset()` implementation |
| `setCacheEntry` replaces entire cache ref | `cache.value = { ...cache.value, [key]: value }` creates a new top-level object — correct for Vue 2.7 ref reactivity (replacing the value triggers watchers). | Optimize by mutating `cache.value[key]` directly — this breaks Vue 2 reactivity |
| `normalizeComment` uses `??` (nullish coalescing) | Preserves legitimate falsy values (0, '', false). `||` would coerce them to defaults — data loss bug. | Switch to `||` for "simpler" fallbacks |

## Callback Design Decisions (Do Not Change)

These Review model callback decisions were verified by a 10-agent expert review (2026-06-04) and confirmed correct. Each has been questioned by agents and re-validated against test-prof docs, Rails source, and PostgreSQL semantics.

### `clear_stale_foreign_keys` — before_validation, not before_save

**Decision:** The defensive callback runs in `before_validation`, not `before_save`.

**Why:** The absence validators on `duplicate_of_review_id` and `addressed_by_rule_id` (review.rb lines 243-249) fire DURING validation. If the callback were `before_save`, validators would reject stale FKs before the callback could clear them — breaking status transitions away from duplicate/addressed_by.

**Do not:** Move to `before_save`. Move to `after_validation`. Add a `triage_status_changed?` guard (breaks self-healing of pre-existing stale data on subsequent saves).

### `clear_stale_foreign_keys` — fires on every save

**Decision:** No `triage_status_changed?` guard. The callback runs on every save regardless of which fields changed.

**Why:** Self-healing. If a prior bug or raw SQL left stale FK data (e.g., `triage_status='concur'` with `duplicate_of_review_id` set), any subsequent save cleans it up automatically. A `changed?` guard would only fire on the transition that caused the staleness — pre-existing stale data would never be healed.

**Do not:** Add a `triage_status_changed?` guard for "performance." The two nil assignments are O(1) — the DB round-trip from `refind: true` is 1000x more expensive.

### `save_intent` — attr_accessor, not validation contexts

**Decision:** `attr_accessor :save_intent` passes controller context to callbacks. Only `:reopen` is checked.

**Why:** Rails validation contexts (`on: :reopen`) scope validators, not `before_save` callbacks. `validation_context` is accessible in callbacks but `update!(attrs, context: :reopen)` is not valid Rails API — you'd need `assign_attributes + save(context:)`, a worse interface. The `attr_accessor` pattern is used by GitLab and Discourse for the same purpose.

**Do not:** Refactor to validation contexts. Set `save_intent` for actions that don't need it (admin_withdraw works via the `adjudicated_at.present?` guard, not save_intent).

### DB CHECK constraints — defense-in-depth

**Decision:** PostgreSQL CHECK constraints (`chk_review_duplicate_fk_consistency`, `chk_review_addressed_by_fk_consistency`) use `IS NOT DISTINCT FROM` (NULL-safe equality) and are added via 2-pass Strong Migrations pattern.

**Why:** Three layers enforce FK consistency: (1) `clear_stale_foreign_keys` callback normalizes on every Rails save, (2) absence validators catch violations if the callback is removed, (3) CHECK constraints catch violations from raw SQL, rake tasks, console, and future bugs. Each layer is deliberately redundant.

**Do not:** Remove any layer. Remove the `validate: false` from the migration (causes ACCESS EXCLUSIVE lock). Use standard SQL `=` instead of `IS NOT DISTINCT FROM` (NULL gap).

## Anti-Patterns

| Don't | Do Instead |
|-------|-----------|
| Options Store (`state()`, `getters`, `actions`) | Setup Store (`defineStore('id', () => { ... })`) |
| Global mutable state outside Pinia | `ref()` inside a store |
| `useStore()` at module top-level | Call inside `setup()`, actions, or getters |
| Circular store deps at setup root | Call `useOtherStore()` inside actions/getters |
| Skip HMR | `acceptHMRUpdate` at bottom of every store file |
| Direct API calls in components | API calls in store actions |
| `@vue/composition-api` package | Vue 2.7 has it built in |
| Pinia 3.x | Pinia 2.x for Vue 2.7 |
| New mixins | Composables with explicit imports |
| `$reset()` without implementation | Define `$reset` manually in Setup Stores |
| Destructuring store without `storeToRefs` | `storeToRefs(store)` for reactive state/getters |
| `mapGetters` (deprecated) | `mapState` (same functionality) |
