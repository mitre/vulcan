# Controls Page - Technical Architecture

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                        ControlsPage.vue                      │
│  - Fetches component + rules on mount                       │
│  - Provides event bus to children                           │
│  - Computes effective permissions                           │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                         Rules.vue                            │
│  - Manages reactive rules array                             │
│  - Handles all rule CRUD via event bus                      │
│  - Sorts rules by rule_id                                   │
└─────────────────────────┬───────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
┌─────────────────┐ ┌───────────┐ ┌─────────────────┐
│  RuleNavigator  │ │RuleEditor │ │ Reference Panel │
│  - List of IDs  │ │ - Forms   │ │ - SRG Info      │
│  - Selection    │ │ - Fields  │ │ - Related       │
│  - Open tabs    │ │           │ │ - Reviews       │
└─────────────────┘ └───────────┘ └─────────────────┘
```

## Event Bus Events

### Rule Lifecycle Events

| Event | Payload | Description |
|-------|---------|-------------|
| `refresh:rule` | `ruleId: number` | Re-fetch rule from API |
| `create:rule` | `{ rule, callback? }` | Create new rule |
| `delete:rule` | `{ ruleId, callback? }` | Soft-delete rule |

### Rule Update Events

| Event | Payload | Description |
|-------|---------|-------------|
| `update:rule` | `rule: IRule` | Replace rule in array |
| `update:check` | `{ rule, check, index }` | Update check at index |
| `update:description` | `{ rule, description, index }` | Update description |
| `update:disaDescription` | `{ rule, description, index }` | Update DISA description |

### Rule Add Events

| Event | Payload | Description |
|-------|---------|-------------|
| `add:check` | `rule: IRule` | Add empty check to rule |
| `add:description` | `rule: IRule` | Add empty description |
| `add:disaDescription` | `rule: IRule` | Add empty DISA description |

### Satisfaction Events

| Event | Payload | Description |
|-------|---------|-------------|
| `addSatisfied:rule` | `{ ruleId, satisfiedByRuleId, callback? }` | Create merge relationship |
| `removeSatisfied:rule` | `{ ruleId, satisfiedByRuleId, callback? }` | Remove merge relationship |

## API Endpoints

### Rules Controller

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/components/:id/controls` | List rules (aliased from rules#index) |
| GET | `/rules/:id` | Get single rule with relations |
| POST | `/components/:id/rules` | Create rule |
| PATCH | `/rules/:id` | Update rule |
| DELETE | `/rules/:id` | Soft-delete rule |
| POST | `/rules/:id/revert` | Revert to historical version |

### Rule Satisfactions Controller

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/rule_satisfactions` | Create satisfaction (merge) |
| DELETE | `/rule_satisfactions/:id` | Remove satisfaction |

## State Management

### Option A: Event Bus Only (Phase 1)

```
ControlsPage
    │
    ├── provides: ruleEvents (mitt)
    │
    └── Rules.vue
        ├── local state: reactiveRules[]
        ├── listens to events
        └── emits events to children
```

**Pros:** Minimal changes, works with existing components
**Cons:** State not shared outside Rules.vue tree

### Option B: Pinia Store (Phase 2)

```
useRulesStore (Pinia)
    │
    ├── state: rules[], currentRule, loading, error
    ├── getters: sortedRules, primaryRules, nestedRules
    └── actions: fetchRules, updateRule, createRule, deleteRule

ControlsPage
    │
    └── uses: useRulesStore()
        │
        └── Rules.vue
            └── uses: useRulesStore()
```

**Pros:** Shared state, devtools support, cleaner architecture
**Cons:** Requires more refactoring

## Component Hierarchy

### Current (Phase 1)

```
ControlsPage.vue (NEW)
└── Rules.vue (EXISTING, modified)
    └── RulesCodeEditorView.vue
        ├── RuleNavigator.vue
        │   └── (rule list items)
        ├── RuleEditorHeader.vue
        ├── RuleEditor.vue
        │   ├── BasicRuleForm.vue
        │   ├── AdvancedRuleForm.vue
        │   ├── RuleDescriptionForm.vue
        │   ├── DisaRuleDescriptionForm.vue
        │   ├── CheckForm.vue
        │   └── AdditionalQuestions.vue
        ├── RuleSatisfactions.vue
        ├── RuleReviews.vue
        ├── RuleHistories.vue
        └── RelatedRulesModal.vue
```

### Future (Phase 3)

```
ControlsPage.vue
├── LayoutSwitcher.vue (NEW)
├── CommandBar.vue (NEW)
│
├── [Table Mode]
│   └── RequirementsTable.vue (NEW)
│       └── RequirementModal.vue (NEW)
│
└── [Focus Mode]
    └── RequirementsFocus.vue (NEW, wraps existing)
        ├── RequirementsNavigator.vue (refactored from RuleNavigator)
        └── RequirementEditor.vue (refactored from RuleEditor)
```

## Type Definitions

### Core Types (from types/rule.ts)

```typescript
interface IRule {
  id: number
  rule_id: string           // e.g., "000001"
  version: string           // SRG version reference
  title: string
  status: RuleStatus
  status_justification?: string
  artifact_description?: string
  vendor_comments?: string
  fixtext?: string
  rule_severity: RuleSeverity
  locked: boolean
  review_requestor_id?: number
  component_id: number
  // Relations
  reviews?: IReview[]
  satisfies?: IRuleSatisfaction[]
  satisfied_by?: IRuleSatisfaction[]
  disa_rule_descriptions?: IDisaRuleDescription[]
  checks?: ICheck[]
}

type RuleStatus =
  | 'Not Yet Determined'
  | 'Applicable - Configurable'
  | 'Applicable - Inherently Meets'
  | 'Applicable - Does Not Meet'
  | 'Not Applicable'

type RuleSeverity = 'unknown' | 'info' | 'low' | 'medium' | 'high'
```

### Constants

```typescript
const STATUSES: RuleStatus[] = [
  'Not Yet Determined',
  'Applicable - Configurable',
  'Applicable - Inherently Meets',
  'Applicable - Does Not Meet',
  'Not Applicable',
]

const SEVERITIES: RuleSeverity[] = ['unknown', 'info', 'low', 'medium', 'high']

const SEVERITIES_MAP: Record<RuleSeverity, string> = {
  unknown: 'unknown',
  info: 'CAT IV',
  low: 'CAT III',
  medium: 'CAT II',
  high: 'CAT I',
}
```

## Migration Notes

### Vue 2 → Vue 3 Changes

| Vue 2 Pattern | Vue 3 Replacement |
|---------------|-------------------|
| `this.$root.$on()` | `mitt` event bus or Pinia |
| `this.$root.$emit()` | `mitt` event bus or Pinia actions |
| Mixins | Composables |
| `_.cloneDeep()` | `structuredClone()` |
| `this.$nextTick()` | `nextTick()` from vue |
| Options API `data()` | `ref()` / `reactive()` |
| Options API `computed` | `computed()` |
| Options API `watch` | `watch()` / `watchEffect()` |

### Bootstrap-Vue → Bootstrap-Vue-Next

| Bootstrap-Vue | Bootstrap-Vue-Next |
|---------------|-------------------|
| `<b-form-checkbox>` | `<BFormCheckbox>` |
| `<b-collapse>` | `<BCollapse>` |
| `<b-tabs>` | `<BTabs>` |
| `v-b-tooltip` | `v-b-tooltip` (same) |

Most components have the same API, but import names are PascalCase.
