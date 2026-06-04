# Comment System Reference Implementation Plan

Complete end-to-end migration of Vulcan's comment system to the four-layer
architecture (API → Store → Composable/Container → Presentational).

## Current State (honest assessment)

**Done:**
- Pinia 2.x installed, `createVulcanApp` helper, 2 packs migrated
- `useCommentsStore` skeleton (fetch/cache/normalize) — not used by any page
- `useCommentReactions` composable — used by 3 of 6 reaction consumers
- `useCommentThread` composable — exists, not wired into CommentThread.vue
- CommentItem/CommentBody/CommentActions/CommentList — built, barely integrated
- CommentDedupBanner uses CommentItem for rendering

**Not done:**
- No consumer fetches through the store
- CommentList is not used by any page
- 3 components still use ReactionToggleMixin
- 14 components make direct API calls
- No cache invalidation on mutations
- No triage/reply/compose actions in the store
- ComponentComments (main table view) untouched
- TriageSplitView/CommentsByRule only swapped mixin, still render inline

## Architecture Decisions (from research)

### Store Scope: Focused Store Pattern

The store owns **state + orchestration**. API calls stay in `api/`. Composables
add component-specific derived state. Direct cross-store calls for 1:1
invalidation relationships.

```
api/reviewsApi.js          ← Pure HTTP (Layer 1, unchanged)
    ↓
stores/comments.js         ← State + cache + orchestration (Layer 2)
    ↓
composables/useXxx.js      ← Component-specific derived state (Layer 2)
    ↓
Container components       ← Wire store to presentational (Layer 3)
    ↓
Presentational components  ← Props in, events out (Layer 4)
```

### What Goes in the Store vs Composable vs Component

| Store | Composable | Component data() |
|-------|-----------|-----------------|
| Comments cache (keyed by component+params) | Filtered/sorted views of store state | UI-only: modal open, filter text input |
| Loading/error state | Reaction toggle (optimistic + rollback) | Expanded/collapsed toggles |
| Triage mutations + cache invalidation | Thread expand/collapse/fetch | Selected row, active comment ID |
| Reply posting + thread cache update | Composer form state | Pagination page number |
| Normalizer (API → stable shape) | Date formatting | Search query debounce |

### Shared Pinia Instance (Critical for Multi-App Pages)

Vulcan has 22 Vue instances. Currently each gets its own `createPinia()`.
For cache invalidation to work across components on the same page (e.g.,
navbar notification count + triage table), all Vue instances on a page
must share ONE Pinia instance.

```javascript
// lib/createVulcanApp.js — shared pinia across all instances
const sharedPinia = createPinia();

export function createVulcanApp({ el, ... }) {
  return new Vue({ el, pinia: sharedPinia });
}
```

This is the Pinia creator's documented pattern for multi-app setups.
State changes in one Vue app instantly reflect in others on the same page.
Turbolinks page transitions create a fresh page, so cross-page state
is not a concern.

### Cache Invalidation: Store Action + Direct Invalidation

When a mutation succeeds (comment posted, triaged, replied), the store
action invalidates its own cache. Consumers watching store state
automatically re-render via Vue reactivity.

```javascript
// Inside store action — direct invalidation (1:1 relationship)
async function postComment(componentId, ruleId, data) {
  const { data: result } = await createRuleReview(ruleId, data);
  invalidateCache(componentId);  // clears stale list cache
  return result;
}
```

No event bus needed. Reactive state IS the communication channel.

### setup() Migration Pattern for Existing Components

```javascript
// BEFORE: Options API with mixin
export default {
  mixins: [ReactionToggleMixin],
  data() { return { rows: [], loading: false } },
  methods: {
    async fetch() { ... getComments() ... },
    toggleReaction(row, kind) { this.submitReactionToggle(...) }
  }
}

// AFTER: setup() + composable, Options API template unchanged
export default {
  props: { componentId: { type: Number, required: true } },
  setup(props) {
    const store = useCommentsStore();
    const { loading, error } = storeToRefs(store);
    const { toggle: toggleReaction } = useCommentReactions();
    return { store, loading, error, toggleReaction };
  },
  data() { return { filterText: '' } },  // UI-only state stays
  mounted() { this.store.fetchComments(this.componentId, {}) }
}
```

### Table vs Media Layout: Separate Rendering, Shared Data Source

ComponentComments uses `b-table` with cell templates — fundamentally different
from CommentItem's `b-media` layout. The solution is NOT to force CommentItem
into table cells. Instead:

- **CommentItem** for card/media layouts (CommentDedupBanner, CommentsByRule detail)
- **Table cell templates** for ComponentComments table view — but using the SAME
  sub-components (CommentAuthorLine, TriageStatusBadge, SectionLabel) directly
- **Both** fetch through the store and use the normalized comment shape

The DRY win is in the data layer (one store, one normalizer) and sub-components
(UserBadge, TriageStatusBadge), not in forcing one layout wrapper on everything.

## Composable System Architecture

The comment system establishes the composable patterns that ALL future Vulcan
features will follow. This is not just a comment refactor — it's the foundation.

### Composable Categories

```
app/javascript/composables/
├── data/                      # Data-fetching composables (wrap store)
│   ├── useComments.js         # Comments for a component (wraps store)
│   ├── useReplies.js          # Reply thread for a comment
│   └── useUserComments.js     # User's own comments
├── mutations/                 # Mutation composables (call API + invalidate)
│   ├── useCommentReactions.js # Optimistic toggle + rollback (DONE)
│   ├── useCommentComposer.js  # Post comment/reply + cache invalidate
│   └── useCommentTriage.js    # Triage decision + cache invalidate
├── ui/                        # UI behavior composables
│   ├── useCommentThread.js    # Expand/collapse/lazy-fetch (DONE)
│   ├── useExpandCollapse.js   # Generic expand/collapse (reusable)
│   └── useFilterPersist.js    # Persist filter state to URL/localStorage
└── format/                    # Pure formatting (no state, replace mixins)
    ├── useDateFormat.js       # friendlyDateTime, friendlyDate
    └── useToast.js            # Toast notification helper
```

### Composable Design Rules

1. **Named `useXxx`** — always a function, always returns an object
2. **Accept reactive refs** — use `toRef(props, 'key')` or `computed` as inputs
3. **Return refs + functions** — consumers destructure what they need
4. **Composables may use stores** — import `useStore()` inside the composable
5. **Composables may use other composables** — compose freely
6. **Never import components** — composables are logic, not rendering
7. **Testable in isolation** — no component mount needed for unit tests
8. **Replace mixins** — every new shared logic uses a composable, never a mixin

### Data Composable Pattern (wraps store for component use)

```javascript
// composables/data/useComments.js
import { computed, toRef, watch } from "vue";
import { storeToRefs } from "pinia";
import { useCommentsStore } from "../../stores/comments";

export function useComments(componentId, options = {}) {
  const store = useCommentsStore();
  const { loading, error } = storeToRefs(store);

  const idRef = toRef(componentId);
  const comments = computed(() => {
    const key = store.cacheKey(idRef.value, options);
    const cached = store.cache[key];
    return cached ? cached.rows.map(store.normalizeComment) : [];
  });

  function fetch(params) {
    return store.fetchComments(idRef.value, params);
  }

  function refresh() {
    store.invalidateCache(idRef.value);
    return fetch(options);
  }

  // Auto-fetch on mount if componentId is set
  if (idRef.value) fetch(options);

  // Re-fetch when componentId changes
  watch(idRef, (newId) => { if (newId) fetch(options); });

  return { comments, loading, error, fetch, refresh };
}
```

### Mutation Composable Pattern (API call + cache invalidation)

```javascript
// composables/mutations/useCommentComposer.js
import { ref } from "vue";
import { createRuleReview, createComponentReview } from "../../api/reviewsApi";
import { useCommentsStore } from "../../stores/comments";

export function useCommentComposer() {
  const submitting = ref(false);
  const submitError = ref(null);

  async function postComment(componentId, ruleId, data) {
    submitting.value = true;
    submitError.value = null;
    try {
      const apiFn = ruleId ? createRuleReview : createComponentReview;
      const target = ruleId || componentId;
      const { data: result } = await apiFn(target, data);

      // Invalidate cache so lists refresh
      const store = useCommentsStore();
      store.invalidateCache(componentId);

      return result;
    } catch (err) {
      submitError.value = err;
      throw err;
    } finally {
      submitting.value = false;
    }
  }

  async function postReply(componentId, ruleId, parentId, comment) {
    return postComment(componentId, ruleId, {
      action: "comment",
      comment,
      responding_to_review_id: parentId,
    });
  }

  return { postComment, postReply, submitting, submitError };
}
```

### Format Composable Pattern (pure, no state — replaces DateFormatMixin)

```javascript
// composables/format/useDateFormat.js
export function useDateFormat() {
  function friendlyDateTime(iso) {
    if (!iso) return "";
    return new Date(iso).toLocaleString();
  }

  function friendlyDate(iso) {
    if (!iso) return "";
    return new Date(iso).toLocaleDateString();
  }

  function relativeTime(iso) {
    if (!iso) return "";
    const diff = Date.now() - new Date(iso).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 60) return `${mins}m ago`;
    const hours = Math.floor(mins / 60);
    if (hours < 24) return `${hours}h ago`;
    return `${Math.floor(hours / 24)}d ago`;
  }

  return { friendlyDateTime, friendlyDate, relativeTime };
}
```

### Migration Path: Mixin → Composable

| Mixin | Composable | Status |
|-------|-----------|--------|
| ReactionToggleMixin | useCommentReactions | 3/6 consumers migrated |
| DateFormatMixin | useDateFormat | Not started (use in ALL new code) |
| AlertMixin | useToast | Not started (cross-cutting) |
| FormMixin | (CSRF setup in createVulcanApp) | Not needed as composable |
| ReplyComposerMixin | useCommentComposer | Not started |
| RoleComparisonMixin | usePermissions | Not started (future) |

Mixins are frozen — no new code uses them. Each consumer migration
swaps the mixin import for the composable. When a mixin has zero
remaining imports, delete it.

## Implementation Phases

### Phase A: Store Expansion (sp:5, ~30 min)

Expand `useCommentsStore` to handle all four fetch patterns and core mutations.

**Fetch:**
- `fetchComments(componentId, params)` — already exists, add rule_id/commentable_type support
- `fetchProjectComments(projectId, params)` — new
- `fetchUserComments(userId, params)` — new
- `fetchReplies(parentReviewId)` — new (for CommentThread)

**Mutations (store actions that invalidate cache):**
- `postComment(componentId, ruleId, data)` → createRuleReview + invalidateCache
- `postComponentComment(componentId, data)` → createComponentReview + invalidateCache
- `triageComment(reviewId, payload)` → triageReview + invalidateCache
- `bulkTriage(reviewIds, payload, componentId)` → bulkTriageReviews + invalidateCache
- `toggleReaction(reviewId, kind)` → toggleReaction API (no cache invalidate — optimistic)

**Not in store (too specialized, stay as direct API calls via composables):**
- Admin actions (withdraw, restore, move, destroy) — rare, complex confirmation UI
- Merge — complex multi-select UI
- Section re-tag — modal-specific
- Adjudicate — always follows triage, not standalone

### Phase B: Composable Completion (sp:3, ~15 min)

Complete the composable layer:
- `useCommentReactions` — done, migrate remaining 3 consumers
- `useCommentThread` — wire into CommentThread.vue (replace its internal state)
- `useCommentComposer` — new, extracts CommentComposerModal's post logic

### Phase C: Consumer Migration — Fetch Through Store (sp:5, ~30 min)

Migrate each consumer's fetch to go through the store. One at a time, test
between each.

Priority order (dependency-driven):
1. **CommentThread.vue** — use `useCommentThread` composable (replace data/methods)
2. **CommentDedupBanner** — fetch through store (already renders via CommentItem)
3. **ComponentComments** — fetch through store (table view, keeps own rendering)
4. **TriageSplitView** — receives rows from parent, no direct fetch to migrate
5. **CommentsByRule** — receives rows from parent, no direct fetch to migrate
6. **RuleReviews** — receives rule.reviews from parent, no direct fetch to migrate
7. **UserComments** — fetch through store (new fetchUserComments action)
8. **CommentComposerModal** — post through store (cache invalidation)
9. **CommentTriageModal** — triage through store (cache invalidation)

### Phase D: Mixin Removal + Final Cleanup (sp:2, ~10 min)

- Remove ReactionToggleMixin from last 3 consumers (CommentTriageModal, RuleReviews, CommentThread)
- Verify ReactionToggleMixin has zero imports → delete the file
- Update all test files to use `createTestingPinia` where applicable
- Run full test suite + Playwright verification

### Phase E: Documentation + Verification (sp:1, ~5 min)

- Update frontend-architecture.md with lessons learned
- Update state-management.md with actual patterns used
- Full Playwright verification: light + dark at 375px, 768px, 1440px
- All consumers verified end-to-end

## Total Estimate

| Phase | Cards | SP | Claude-pace |
|-------|-------|----|-------------|
| A: Store expansion | 1 | 5 | ~30 min |
| B: Composable completion | 1 | 3 | ~15 min |
| C: Consumer migration (fetch) | 1 | 5 | ~30 min |
| D: Mixin removal + cleanup | 1 | 2 | ~10 min |
| E: Documentation + verification | 1 | 1 | ~5 min |
| **Total** | **5** | **16** | **~90 min** |

## Testing Strategy

**Store tests:** `setActivePinia(createPinia())` + mock API layer. Test each
action's cache behavior, error handling, and normalizer output.

**Component tests:** `createTestingPinia({ initialState, stubActions: false })`
for integration tests that verify the component calls the right store action.
Mock specific actions with `vi.spyOn(store, 'action').mockResolvedValue(data)`.

**Vue 2.7 gotcha:** Stubbed actions return `undefined`, not Promises. Always
mock return values when the component `await`s the action.

## Anti-Patterns to Avoid

- Do NOT put ALL mutations in the store — admin actions are too specialized
- Do NOT force CommentItem on the table view — use shared sub-components instead
- Do NOT remove mixins until composable is proven (run both briefly during migration)
- Do NOT invalidate cache on failed mutations — use `$onAction.after()` pattern
- Do NOT batch all consumer migrations — one at a time, test between each
