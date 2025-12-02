# Performance Optimization Plan: Rules API

## Problem Statement

The Controls page for large components (e.g., Container SRG with 264 rules) was taking 7-12 seconds to load, making the application unusable for real work.

---

## Root Cause Analysis

### Profiling Results (Before Optimization)

| Operation | Time | Notes |
|-----------|------|-------|
| Database query (eager_load) | 0.3s | Fast - not the problem |
| JSON serialization (as_json) | 6-7s | **THE PROBLEM** |
| Total | 7+ seconds | Unacceptable |

### Specific Issues Found

1. **Duplicate method calls**: `methods: %i[satisfies satisfied_by]` was calling these TWICE (once via methods param, once already in Rule#as_json merge)

2. **N+1 on SRG lookup**: `SecurityRequirementsGuide.find_by(id: srg_rule.security_requirements_guide_id)` runs for EACH rule during serialization

3. **Wrong data at wrong time**: Loading ALL data (histories, full descriptions, all associations) for the table view when it only needs: `id`, `rule_id`, `status`, `severity`, `title`, `is_merged`

4. **`histories` method**: Runs a query per rule (~36ms each × 264 = 9.5s worst case)

---

## Solution Architecture

### Industry Best Practice

**Different serializers for different endpoints** - list views get slim data, detail views get full data.

Reference: [Investigating the Performance of a Problematic Rails API Endpoint](https://dev.to/mculp/investigating-the-performance-of-a-problematic-rails-api-endpoint-3a65)
- Their result: 7,795ms → 150ms (98% reduction)

### 4-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 1: DATABASE                                               │
│ - No changes needed (queries already fast with eager_load)      │
│ - Future: Consider materialized views for dashboards            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 2: CONTROLLER + SERIALIZERS (Blueprinter)                 │
│                                                                 │
│ Index Action (list):                                            │
│   - Uses RuleIndexBlueprint (slim)                              │
│   - Only loads :satisfied_by association                        │
│   - Returns ~84 KB for 264 rules                                │
│                                                                 │
│ Show Action (detail):                                           │
│   - Uses RuleBlueprint (full)                                   │
│   - Eager loads all associations                                │
│   - Returns ~8 KB per rule                                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3: STORE (Pinia)                                          │
│                                                                 │
│ State:                                                          │
│   - rules: ISlimRule[]           (list data - always loaded)    │
│   - fullRulesCache: Map<id, IRule> (detail data - on demand)    │
│                                                                 │
│ Actions:                                                        │
│   - fetchRules(componentId)      → populates rules (slim)       │
│   - fetchFullRule(id)            → fetches & caches full data   │
│   - getFullRule(id)              → returns cached or fetches    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 4: COMPOSABLE (useRules)                                  │
│                                                                 │
│ Orchestration:                                                  │
│   - On page load: fetch slim rules                              │
│   - On rule select: check cache, fetch full if needed           │
│   - Exposes currentRule (full data) to components               │
│                                                                 │
│ Pattern: Stale-while-revalidate                                 │
│   - Show cached data immediately                                │
│   - Fetch fresh in background if stale                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 5: COMPONENTS                                             │
│                                                                 │
│ RequirementsTable.vue:                                          │
│   - Uses slim data (rules from store)                           │
│   - No changes needed                                           │
│                                                                 │
│ RequirementEditor.vue:                                          │
│   - Uses full data (currentRule from composable)                │
│   - Composable handles fetching                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Status

### ✅ Completed (Session 9)

#### 1. Blueprinter Gem
- Added to Gemfile: `gem 'blueprinter'`
- Installed successfully

#### 2. Blueprints Created
Location: `app/blueprints/`

| File | Purpose |
|------|---------|
| `rule_index_blueprint.rb` | Slim serializer for list view |
| `rule_blueprint.rb` | Full serializer for detail view |
| `review_blueprint.rb` | Review association |
| `disa_rule_description_blueprint.rb` | DISA description association |
| `check_blueprint.rb` | Check association |
| `rule_satisfaction_blueprint.rb` | Satisfies/satisfied_by |
| `srg_rule_blueprint.rb` | SRG rule attributes |

#### 3. Controller Updated
File: `app/controllers/rules_controller.rb`

```ruby
# Index - slim data
def index
  respond_to do |format|
    format.html { ... }
    format.json do
      @rules = @component.rules.includes(:satisfied_by)
      render json: RuleIndexBlueprint.render(@rules)
    end
  end
end

# Show - full data
def show
  render json: RuleBlueprint.render(@rule)
end
```

#### 4. Performance Results (Backend)

| Endpoint | Before | After | Improvement |
|----------|--------|-------|-------------|
| Index (264 rules) | 7,000ms | 253ms | **28x faster** |
| Show (1 rule) | 100ms | 13ms | **8x faster** |
| JSON size (index) | 7,076 KB | 84 KB | **84x smaller** |

---

### 🔲 TODO (Next Session)

#### 1. Frontend Types
File: `app/javascript/types/rule.ts`

Add:
```typescript
export interface ISlimRule {
  id: number
  rule_id: string
  version: string
  title: string
  status: RuleStatus
  rule_severity: RuleSeverity
  locked: boolean
  review_requestor_id?: number | null
  is_merged: boolean
}
```

#### 2. Frontend Store
File: `app/javascript/stores/rules.store.ts`

Changes:
```typescript
// State
const rules = ref<ISlimRule[]>([])  // Slim data for list
const fullRulesCache = ref<Map<number, IRule>>(new Map())  // Full data cache
const currentRule = ref<IRule | null>(null)  // Currently selected (full)

// Actions
async function fetchRules(componentId: number) {
  // Returns slim data now
  const response = await rulesApi.getComponentRules(componentId)
  rules.value = response.data  // ISlimRule[]
}

async function fetchFullRule(id: number): Promise<IRule> {
  // Check cache first
  if (fullRulesCache.value.has(id)) {
    return fullRulesCache.value.get(id)!
  }
  // Fetch and cache
  const response = await rulesApi.getRule(id)
  fullRulesCache.value.set(id, response.data)
  return response.data
}

async function selectRule(id: number) {
  const fullRule = await fetchFullRule(id)
  currentRule.value = fullRule
}
```

#### 3. Composable Update
File: `app/javascript/composables/useRules.ts`

Orchestrate the slim/full data flow.

#### 4. Testing
- Verify table loads in <500ms
- Verify Focus mode loads rule in <200ms
- Verify switching rules uses cache (instant)

---

## Reference Sources

### Vue 3 / Pinia Patterns
- [Managing Large Datasets in Nuxt/Vue 3](https://felixastner.com/articles/managing-large-datasets-nuxt-vue3)
  - Key: Lazy loading, caching previously loaded items
- [TanStack Query Caching](https://tanstack.com/query/v4/docs/framework/react/guides/caching)
  - Key: Stale-while-revalidate pattern
- [Pinia Cached Store](https://github.com/iWeltAG/pinia-cached-store)
  - Key: Transparent caching with $load action

### Rails API Patterns
- [Investigating Problematic Rails API Endpoint](https://dev.to/mculp/investigating-the-performance-of-a-problematic-rails-api-endpoint-3a65)
  - Key: Index-specific serializer, 98% performance improvement
- [Multiple Serializers per Model](https://stackoverflow.com/questions/12485404/how-to-implement-multiple-different-serializers-for-same-model-using-activemodel)
  - Key: `each_serializer:` for collections, `serializer:` for single
- [Choosing Rails JSON Serializer](https://frankgroeneveld.nl/2021/02/05/choosing-rails-json-serializer-for-your-api-in-2021/)
  - Key: Blueprinter recommended for most cases

### PostgreSQL (Future Reference)
- [Materialized Views in Rails](https://pganalyze.com/blog/materialized-views-ruby-rails)
  - Key: Good for dashboards, not needed for this case
- [Speed up with Materialized Views](https://www.sitepoint.com/speed-up-with-materialized-views-on-postgresql-and-rails/)
  - Key: Use scenic gem, refresh concurrently

---

## Metrics to Track

### Before Optimization (Baseline)
- Index (264 rules): **7,000ms**
- Show (1 rule): **100ms**
- Index JSON size: **7,076 KB**
- User perceived load time: **12-15 seconds**

### After Backend Optimization (Current)
- Index (264 rules): **253ms** ✅
- Show (1 rule): **13ms** ✅
- Index JSON size: **84 KB** ✅
- User perceived load time: **TBD** (need frontend update)

### Target (After Frontend Update)
- Page load (table visible): **<500ms**
- Focus mode (rule detail): **<200ms**
- Rule switching (cached): **<50ms**

---

## Files Changed/Created

### Created
- `app/blueprints/rule_index_blueprint.rb`
- `app/blueprints/rule_blueprint.rb`
- `app/blueprints/review_blueprint.rb`
- `app/blueprints/disa_rule_description_blueprint.rb`
- `app/blueprints/check_blueprint.rb`
- `app/blueprints/rule_satisfaction_blueprint.rb`
- `app/blueprints/srg_rule_blueprint.rb`
- `docs-spa/PERFORMANCE-OPTIMIZATION-PLAN.md` (this file)

### Modified
- `Gemfile` - Added blueprinter gem
- `app/controllers/rules_controller.rb` - Updated index/show actions
- `app/models/rule.rb` - Added disa_rule_descriptions/checks to as_json (Session 8)

### To Modify (Next Session)
- `app/javascript/types/rule.ts`
- `app/javascript/stores/rules.store.ts`
- `app/javascript/composables/useRules.ts`
