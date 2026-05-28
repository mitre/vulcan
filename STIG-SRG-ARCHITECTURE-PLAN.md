# STIG/SRG Architecture Refactor - COMPLETED

## Session: 2025-11-27

## Status: COMPLETED

The unified benchmark architecture has been implemented. STIGs and SRGs now share common components, composables, and types.

## What Was Implemented

### 1. Unified Types (`types/benchmark.ts`)
- `BenchmarkType` - discriminator ('stig' | 'srg')
- `IBenchmark` - unified benchmark interface
- `IBenchmarkListItem` - list item for index pages
- `IBenchmarkRule` - unified rule interface
- Type adapter functions: `stigToBenchmark()`, `srgToBenchmark()`

### 2. Unified Components (`components/benchmarks/`)
All Vue 3 Composition API + Bootstrap-Vue-Next:

| Component | Purpose |
|-----------|---------|
| `BenchmarkList.vue` | Index page - header with count, upload button, table |
| `BenchmarkTable.vue` | Searchable, paginated table with delete modal |
| `BenchmarkUpload.vue` | Upload modal for XCCDF XML files |
| `BenchmarkViewer.vue` | Show page - 3-column layout |
| `RuleList.vue` | Left sidebar - filterable rule list |
| `RuleDetails.vue` | Middle panel - vuln discussion, check, fix |
| `RuleOverview.vue` | Right sidebar - rule metadata |

### 3. Unified Composable (`composables/useBenchmarks.ts`)
- Wraps `useStigs()` and `useSrgs()`
- Converts to unified `IBenchmarkListItem[]` format
- Same API for both types

### 4. Updated Pages
- `pages/stigs/IndexPage.vue` - uses `BenchmarkList` via `useBenchmarks('stig')`
- `pages/srgs/IndexPage.vue` - uses `BenchmarkList` via `useBenchmarks('srg')`
- `pages/stigs/ShowPage.vue` - uses `BenchmarkViewer` with `stigToBenchmark()`
- `pages/srgs/ShowPage.vue` - NEW! uses `BenchmarkViewer` with `srgToBenchmark()`

### 5. Added SRG Show Route
```typescript
{
  path: '/srgs/:id',
  name: 'security_requirements_guide',
  component: () => import('@/pages/srgs/ShowPage.vue'),
}
```

### 6. Deleted Old Components
- `components/stigs/` - entire directory removed
- `components/security_requirements_guides/` - entire directory removed

## Architecture

```
LAYER 1: API (unchanged)
├── stigs.api.ts
└── srgs.api.ts

LAYER 2: STORES (unchanged)
├── stigs.store.ts
└── srgs.store.ts

LAYER 3: COMPOSABLES
├── useStigs.ts (unchanged)
├── useSrgs.ts (unchanged)
└── useBenchmarks.ts (NEW - unified interface)

LAYER 4: PAGES (updated)
├── pages/stigs/IndexPage.vue (uses BenchmarkList)
├── pages/stigs/ShowPage.vue (uses BenchmarkViewer)
├── pages/srgs/IndexPage.vue (uses BenchmarkList)
└── pages/srgs/ShowPage.vue (NEW - uses BenchmarkViewer)

LAYER 5: COMPONENTS (unified)
└── components/benchmarks/
    ├── BenchmarkList.vue
    ├── BenchmarkTable.vue
    ├── BenchmarkUpload.vue
    ├── BenchmarkViewer.vue
    ├── RuleList.vue
    ├── RuleDetails.vue
    └── RuleOverview.vue
```

## Data Flow

```
User clicks /stigs or /srgs
      ↓
Vue Router → IndexPage.vue
      ↓
useBenchmarks(type) composable
      ↓
useStigs/useSrgs composable
      ↓
stigs.store/srgs.store (Pinia)
      ↓
stigs.api/srgs.api
      ↓
Rails Controller → JSON
      ↓
Store updates state
      ↓
Composable converts to IBenchmarkListItem[]
      ↓
BenchmarkList receives props
      ↓
BenchmarkTable renders
```

## Key Patterns Used

1. **Props Down, Events Up**: Components receive data via props, emit events for actions
2. **Composables Bridge**: Page → Composable → Store → API
3. **Type Discriminator**: `type: 'stig' | 'srg'` prop determines behavior
4. **Bootstrap-Vue-Next**: `BTable`, `BModal`, `BPagination`, `BButton`, etc.
5. **Vue 3 Composition API**: `<script setup lang="ts">`

## Commands

```bash
pnpm build      # Build
pnpm lint       # Lint
foreman start -f Procfile.dev  # Dev server
```

## Future Improvements

1. **Rails API**: Consider unified `/benchmarks` endpoint with type param
2. **Dark Mode**: Bootstrap 5.3+ native `data-bs-theme` support
3. **Navbar Migration**: Migrate to Vue 3 Composition API + Bootstrap-Vue-Next
