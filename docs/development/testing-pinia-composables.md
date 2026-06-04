# Testing Pinia Stores & Composables

Testing guide for Vulcan's Pinia stores, composables, and components that use them. Based on Pinia cookbook, Vue testing docs, and Vitest patterns.

## Dependencies

```bash
yarn add -D @pinia/testing
```

## Test Infrastructure

Vulcan uses:
- **Vitest 4.x** with jsdom environment
- **@vue/test-utils v1** (Vue 2 compatible)
- **localVue** pattern via `spec/javascript/testHelper.js`
- **setup.js** for global BootstrapVue, CSRF mock, localStorage polyfill

### Extended Test Helper (add Pinia support)

```javascript
// spec/javascript/testHelper.js — add PiniaVuePlugin
import { createLocalVue } from "@vue/test-utils";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import { PiniaVuePlugin } from "pinia";

const localVue = createLocalVue();
localVue.use(PiniaVuePlugin);
localVue.use(BootstrapVue);
localVue.use(IconsPlugin);

export { localVue };
```

---

## 1. Unit Testing Stores

Stores are tested in isolation — no component mount needed. Create a fresh Pinia per test.

```javascript
import { setActivePinia, createPinia } from "pinia";
import { useCommentsStore } from "@/stores/comments";
import { getComments } from "@/api/componentsApi";

vi.mock("@/api/componentsApi", () => ({
  getComments: vi.fn(),
}));

describe("useCommentsStore", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it("fetches and caches comments", async () => {
    getComments.mockResolvedValue({ data: { rows: [{ id: 1 }] } });
    const store = useCommentsStore();

    await store.fetchComments(38, {});

    expect(getComments).toHaveBeenCalledWith(38, {});
    expect(Object.keys(store.cache)).toHaveLength(1);
  });

  it("returns cached data on second call (no re-fetch)", async () => {
    getComments.mockResolvedValue({ data: { rows: [] } });
    const store = useCommentsStore();

    await store.fetchComments(38, {});
    await store.fetchComments(38, {});

    expect(getComments).toHaveBeenCalledTimes(1);
  });

  it("invalidateCache clears entries for componentId", async () => {
    getComments.mockResolvedValue({ data: { rows: [] } });
    const store = useCommentsStore();

    await store.fetchComments(38, { status: "all" });
    await store.fetchComments(38, { status: "pending" });
    expect(Object.keys(store.cache)).toHaveLength(2);

    store.invalidateCache(38);
    expect(Object.keys(store.cache)).toHaveLength(0);
  });
});
```

### Testing Store Actions with Side Effects

```javascript
it("postComment calls API and invalidates cache", async () => {
  const mockResponse = { data: { toast: { title: "Posted" } } };
  createRuleReview.mockResolvedValue(mockResponse);
  getComments.mockResolvedValue({ data: { rows: [{ id: 1 }] } });

  const store = useCommentsStore();

  // Pre-populate cache
  await store.fetchComments(38, {});
  expect(Object.keys(store.cache)).toHaveLength(1);

  // Post comment — should invalidate cache
  await store.postComment(38, 100, { comment: "test" });

  expect(createRuleReview).toHaveBeenCalledWith(100, { comment: "test" });
  expect(Object.keys(store.cache)).toHaveLength(0); // invalidated
});
```

### Testing the Normalizer

```javascript
it("normalizeComment maps API fields to stable shape", () => {
  const store = useCommentsStore();
  const raw = {
    id: 42,
    author_name: "John",
    commenter_email: "john@example.com",
    comment: "text",
    triage_status: "pending",
  };

  const normalized = store.normalizeComment(raw);

  expect(normalized.id).toBe(42);
  expect(normalized.authorName).toBe("John");
  expect(normalized.authorEmail).toBe("john@example.com");
  expect(normalized.text).toBe("text");
  expect(normalized.triageStatus).toBe("pending");
});
```

---

## 2. Unit Testing Composables

### Simple Composables (no lifecycle hooks)

Test directly — no mount needed:

```javascript
import { useCommentReactions } from "@/composables/useCommentReactions";
import { toggleReaction } from "@/api/reviewsApi";

vi.mock("@/api/reviewsApi", () => ({
  toggleReaction: vi.fn(),
}));

describe("useCommentReactions", () => {
  it("optimistically updates and reverts on error", async () => {
    toggleReaction.mockRejectedValue(new Error("500"));

    const { toggle } = useCommentReactions();
    const apply = vi.fn();
    const prev = { up: 0, down: 0, mine: null };

    await toggle(42, "up", prev, apply);

    // First call: optimistic update
    expect(apply).toHaveBeenCalledTimes(2);
    // Last call: revert to prev
    expect(apply).toHaveBeenLastCalledWith(prev);
  });
});
```

### Composables with Lifecycle Hooks

Use a `withSetup` helper (Vue docs pattern):

```javascript
// spec/javascript/helpers/withSetup.js
import Vue from "vue";

export function withSetup(composable) {
  let result;
  const vm = new Vue({
    setup() {
      result = composable();
      return () => {};
    },
  });
  vm.$mount();
  return [result, vm];
}
```

Usage:

```javascript
import { withSetup } from "@test/helpers/withSetup";
import { useCommentThread } from "@/composables/useCommentThread";

it("fetches replies on toggle", async () => {
  const [thread, vm] = withSetup(() => useCommentThread(42));

  await thread.toggle();

  expect(thread.expanded.value).toBe(true);
  vm.$destroy();
});
```

### Composables that Use Pinia Stores

Set up Pinia before calling the composable:

```javascript
import { setActivePinia, createPinia } from "pinia";

beforeEach(() => {
  setActivePinia(createPinia());
});

it("useComments fetches through store", () => {
  const { comments, loading } = useComments(38);
  expect(comments.value).toEqual([]);
  expect(loading.value).toBe(false);
});
```

---

## 3. Component Testing with Pinia

### Using createTestingPinia (recommended for component tests)

```javascript
import { mount } from "@vue/test-utils";
import { createTestingPinia } from "@pinia/testing";
import { localVue } from "@test/testHelper";
import { useCommentsStore } from "@/stores/comments";
import MyComponent from "@/components/MyComponent.vue";

describe("MyComponent", () => {
  it("renders comments from store", () => {
    const pinia = createTestingPinia({
      initialState: {
        comments: {
          cache: { "38:{}": { rows: [{ id: 1, comment: "test" }] } },
          loading: false,
          error: null,
        },
      },
      stubActions: false,
      createSpy: vi.fn,
    });

    const wrapper = mount(MyComponent, {
      localVue,
      pinia,
      propsData: { componentId: 38 },
    });

    expect(wrapper.text()).toContain("test");
  });
});
```

### Vue 2.7 Gotcha: Stubbed Actions Return undefined

By default, `createTestingPinia` stubs all actions — they become spies that return `undefined`. If your component `await`s a store action, it will get `undefined` instead of a Promise.

```javascript
// BAD — component calls await store.fetchComments() which returns undefined
createTestingPinia() // stubActions: true by default

// GOOD — Option 1: let actions run
createTestingPinia({ stubActions: false })

// GOOD — Option 2: mock the return value
const store = useCommentsStore();
store.fetchComments.mockResolvedValue({
  rows: [{ id: 1 }],
  pagination: { total: 1 },
});
```

### Providing Pinia to Vue 2 mount()

With `@vue/test-utils` v1, pass `pinia` as a mount option (not inside `global.plugins`):

```javascript
// Vue 2 pattern (test-utils v1)
const wrapper = mount(Component, {
  localVue,
  pinia: createTestingPinia({ createSpy: vi.fn }),
  propsData: { ... },
});

// NOT Vue 3 pattern (test-utils v2) — this won't work in Vue 2:
// mount(Component, { global: { plugins: [pinia] } })
```

---

## 4. Testing Patterns by Layer

### Layer 1: API (Pure HTTP)

API functions are mocked in store/composable tests. No separate API tests needed unless the function has complex request construction.

```javascript
vi.mock("@/api/reviewsApi", () => ({
  createRuleReview: vi.fn(),
  triageReview: vi.fn(),
  toggleReaction: vi.fn(),
}));
```

### Layer 2: Store (State + Orchestration)

```javascript
// Fresh pinia per test
beforeEach(() => setActivePinia(createPinia()));

// Test: action calls API, updates state, invalidates cache
// Test: normalizer produces stable shape
// Test: error handling sets error state
// Test: loading flag lifecycle
// Test: cache hit/miss behavior
```

### Layer 2: Composable (Shared Logic)

```javascript
// Simple: test directly, no mount
// With lifecycle hooks: use withSetup helper
// With store dependency: setActivePinia first
// Test: return value structure (refs + functions)
// Test: optimistic update + rollback
// Test: debounce/throttle behavior
// Test: cleanup on unmount (if applicable)
```

### Layer 3: Container Components

```javascript
// Use createTestingPinia with initialState
// Verify: component calls correct store action on mount
// Verify: component passes store state to child via props
// Verify: component handles store errors gracefully
// Verify: event handlers dispatch correct store actions
```

### Layer 4: Presentational Components

```javascript
// No Pinia needed — pure props/events
// Use mount() with propsData
// Verify: renders correct sub-components
// Verify: emits correct events on interaction
// Verify: slot content renders
// Verify: conditional rendering based on props
```

---

## 5. Mocking Patterns

### Mock API Layer (most common)

```javascript
vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
    defaults: { headers: { common: {} } },
  },
}));
```

### Mock Specific Store Action

```javascript
const store = useCommentsStore();
vi.spyOn(store, "fetchComments").mockResolvedValue({
  rows: [],
  pagination: { total: 0 },
});
```

### Mock Composable Return Value

```javascript
vi.mock("@/composables/useCommentReactions", () => ({
  useCommentReactions: () => ({
    toggle: vi.fn(),
    pending: { value: new Set() },
  }),
}));
```

---

## 6. Anti-Patterns

| Don't | Do Instead |
|-------|-----------|
| Test store via component mount | Test store directly with `setActivePinia` |
| Skip mocking API in store tests | Always mock — tests must be offline-capable |
| Use `stubActions: true` when component awaits actions | Use `stubActions: false` or mock return values |
| Share Pinia instance across tests | Fresh `createPinia()` in `beforeEach` |
| Test composable by mounting a component | Test composable directly (or use `withSetup`) |
| Assert `toBeTruthy()` on store state | Assert specific values (`toBe`, `toEqual`) |
| Test implementation details (internal refs) | Test public interface (return values, side effects) |
| Mount with `global.plugins` (Vue 3 syntax) | Use `pinia` mount option (Vue 2 syntax) |

---

## 7. Checklist for New Store/Composable

Before closing any card that adds a store or composable:

- [ ] `@pinia/testing` is in devDependencies
- [ ] `PiniaVuePlugin` registered in `testHelper.js`
- [ ] Store tests use `setActivePinia(createPinia())` per test
- [ ] All API calls mocked (no network in tests)
- [ ] Every action tested: success path + error path
- [ ] Normalizer tested with specific field assertions
- [ ] Cache behavior tested (hit, miss, invalidate)
- [ ] Loading/error state lifecycle tested
- [ ] Composable tested without component mount
- [ ] Component tests use `createTestingPinia` with `createSpy: vi.fn`
- [ ] No `stubActions: true` when component awaits actions
- [ ] All assertions use specific values, not `toBeTruthy`
