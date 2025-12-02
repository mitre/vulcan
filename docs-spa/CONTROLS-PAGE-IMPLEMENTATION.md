# Controls Page - Implementation Plan

## Overview

Phased approach to rebuild the Controls (Requirements) editing page in Vue 3 SPA.

## Current State Analysis

### What Exists
- `Rules.vue` - Main container component (Vue 2 Options API)
- `RulesCodeEditorView.vue` - Editor layout with navigator
- `RuleEditor.vue` - Form for editing requirement fields
- `RuleNavigator.vue` - Left sidebar list
- Multiple form components in `rules/forms/`
- Mixins: AlertMixin, FormMixin, SortRulesMixin, SelectedRulesMixin

### Issues to Fix
1. **Vue 2 Event Bus** - `$root.$on`/`$root.$emit` doesn't exist in Vue 3
2. **Mixins** - Should be composables in Vue 3
3. **No TypeScript** - All plain JavaScript
4. **No loading states** - Data expected from Rails, no async handling
5. **Lodash dependency** - `_.cloneDeep()` can use native `structuredClone()`

---

## Phase 1: Foundation (Get It Working)

**Goal:** Restore controls editing functionality in SPA

**Estimated Time:** 2-3 hours

### 1.1 Create Event Bus (mitt)

```typescript
// app/javascript/utils/eventBus.ts
import mitt from 'mitt'

type RuleEvents = {
  'refresh:rule': number
  'update:rule': any
  'update:check': { rule: any; check: any; index: number }
  'update:description': { rule: any; description: any; index: number }
  'update:disaDescription': { rule: any; description: any; index: number }
  'add:check': any
  'add:description': any
  'add:disaDescription': any
  'create:rule': { rule: any; callback?: Function }
  'delete:rule': { ruleId: number; callback?: Function }
  'addSatisfied:rule': { ruleId: number; satisfiedByRuleId: number; callback?: Function }
  'removeSatisfied:rule': { ruleId: number; satisfiedByRuleId: number; callback?: Function }
}

export const ruleEvents = mitt<RuleEvents>()
```

### 1.2 Create Rules API

```typescript
// app/javascript/apis/rules.api.ts
import { http } from '@/services/http.service'
import type { IRule, IRuleUpdate } from '@/types'

export function getRule(id: number) {
  return http.get<IRule>(`/rules/${id}`)
}

export function getComponentRules(componentId: number) {
  return http.get<IRule[]>(`/components/${componentId}/rules`)
}

export function updateRule(id: number, data: IRuleUpdate) {
  return http.patch(`/rules/${id}`, { rule: data })
}

export function createRule(componentId: number, data: Partial<IRule>) {
  return http.post(`/components/${componentId}/rules`, { rule: data })
}

export function deleteRule(id: number) {
  return http.delete(`/rules/${id}`)
}

export function revertRule(id: number, auditId: number, fields: string[], comment?: string) {
  return http.post(`/rules/${id}/revert`, { audit_id: auditId, fields, audit_comment: comment })
}
```

### 1.3 Implement ControlsPage.vue

```typescript
// app/javascript/pages/components/ControlsPage.vue
<script setup lang="ts">
import { computed, onMounted, provide, ref } from 'vue'
import { useRoute } from 'vue-router'
import { getComponent } from '@/apis/components.api'
import { getProject } from '@/apis/projects.api'
import Rules from '@/components/rules/Rules.vue'
import { useAuthStore } from '@/stores'
import { ruleEvents } from '@/utils/eventBus'

// Provide event bus to child components
provide('ruleEvents', ruleEvents)

// Constants
const STATUSES = [
  'Not Yet Determined',
  'Applicable - Configurable',
  'Applicable - Inherently Meets',
  'Applicable - Does Not Meet',
  'Not Applicable',
]
const SEVERITIES = ['unknown', 'info', 'low', 'medium', 'high']
const SEVERITIES_MAP = {
  unknown: 'unknown',
  info: 'CAT IV',
  low: 'CAT III',
  medium: 'CAT II',
  high: 'CAT I',
}

const route = useRoute()
const authStore = useAuthStore()

const component = ref(null)
const project = ref(null)
const loading = ref(true)
const error = ref(null)

// ... data loading and permission computation
</script>
```

### 1.4 Update Rules.vue for Event Bus

Replace all `this.$root.$on` with injected event bus:

```typescript
// In Rules.vue setup or created
import { inject } from 'vue'
const ruleEvents = inject('ruleEvents')

// Replace:
// this.$root.$on('refresh:rule', this.refreshRule)
// With:
ruleEvents.on('refresh:rule', this.refreshRule)

// In beforeUnmount, clean up:
ruleEvents.off('refresh:rule', this.refreshRule)
```

---

## Phase 2: Modernize State Management

**Goal:** Clean Vue 3 architecture with Pinia and composables

**Estimated Time:** 4-6 hours

### 2.1 Create useRulesStore (Pinia)

```typescript
// app/javascript/stores/rules.store.ts
import { defineStore } from 'pinia'
import * as rulesApi from '@/apis/rules.api'
import type { IRule, IRulesState } from '@/types'

export const useRulesStore = defineStore('rules', {
  state: (): IRulesState => ({
    rules: [],
    currentRule: null,
    loading: false,
    error: null,
  }),

  getters: {
    sortedRules: (state) => [...state.rules].sort((a, b) =>
      a.rule_id.localeCompare(b.rule_id)
    ),
    primaryRules: (state) => state.rules.filter(r => !r.satisfied_by?.length),
    nestedRules: (state) => state.rules.filter(r => r.satisfied_by?.length > 0),
  },

  actions: {
    async fetchRules(componentId: number) { /* ... */ },
    async updateRule(id: number, data: IRuleUpdate) { /* ... */ },
    async createRule(componentId: number, data: Partial<IRule>) { /* ... */ },
    async deleteRule(id: number) { /* ... */ },
  },
})
```

### 2.2 Create useRuleSelection Composable

```typescript
// app/javascript/composables/useRuleSelection.ts
import { computed, ref, watch } from 'vue'

export function useRuleSelection(componentId: number, rules: Ref<IRule[]>) {
  const selectedRuleId = ref<number | null>(null)
  const openRuleIds = ref<number[]>([])

  // Load from localStorage
  const storageKey = `selectedRuleId-${componentId}`
  // ...

  const selectedRule = computed(() =>
    rules.value.find(r => r.id === selectedRuleId.value) || null
  )

  function selectRule(id: number) { /* ... */ }
  function deselectRule(id: number) { /* ... */ }

  return {
    selectedRuleId,
    selectedRule,
    openRuleIds,
    selectRule,
    deselectRule,
  }
}
```

### 2.3 Migrate Rules.vue to Composition API

Convert from Options API with mixins to Composition API with composables.

### 2.4 Add "Hide Nested" Toggle

```typescript
const showNested = ref(true)

const visibleRules = computed(() => {
  if (showNested.value) return sortedRules.value
  return sortedRules.value.filter(r => !r.satisfied_by?.length)
})
```

---

## Phase 3: New Layouts

**Goal:** Improved UX with Table (triage) and Focus (authoring) modes

**Estimated Time:** 8-12 hours

### 3.1 Build Table View Component

```
RequirementsTable.vue
├── Sortable columns (Status, ID, Title, Severity)
├── Filterable by status
├── Groupable by status
├── Row click opens modal
└── Status indicators with colors
```

### 3.2 Add Layout Switcher

```vue
<template>
  <div class="layout-switcher">
    <button :class="{ active: layout === 'table' }" @click="layout = 'table'">
      📋 Table
    </button>
    <button :class="{ active: layout === 'focus' }" @click="layout = 'focus'">
      ✏️ Focus
    </button>
  </div>

  <RequirementsTable v-if="layout === 'table'" ... />
  <RequirementsFocus v-else ... />
</template>
```

### 3.3 Consolidate Command Bar

Single component with all actions, used in both layouts.

### 3.4 Add Filtering/Grouping

- Filter by: Status, Severity, Review state, Locked state
- Group by: Status, Severity
- Search: Title, ID, content

---

## File Structure (Final)

```
app/javascript/
├── apis/
│   └── rules.api.ts              # NEW
├── composables/
│   ├── useRuleSelection.ts       # NEW
│   └── useRules.ts               # NEW (optional, wraps store)
├── stores/
│   └── rules.store.ts            # NEW
├── utils/
│   └── eventBus.ts               # NEW
├── pages/
│   └── components/
│       └── ControlsPage.vue      # NEW (replaces stub)
├── components/
│   └── rules/
│       ├── Rules.vue             # MODIFIED (event bus)
│       ├── RequirementsTable.vue # NEW (Phase 3)
│       ├── RequirementsFocus.vue # NEW (Phase 3)
│       ├── CommandBar.vue        # NEW (Phase 3)
│       └── ... (existing)
└── types/
    └── rule.ts                   # EXISTS (verify complete)
```

---

## Testing Checklist

### Phase 1
- [ ] ControlsPage loads component data
- [ ] Rules list displays in navigator
- [ ] Can select a rule
- [ ] Can edit and save a rule
- [ ] Toast notifications work
- [ ] Navigation persists across page loads

### Phase 2
- [ ] Pinia store manages rule state
- [ ] Rule updates reflect immediately
- [ ] "Hide nested" toggle works
- [ ] No memory leaks (event cleanup)

### Phase 3
- [ ] Table view displays all rules
- [ ] Can sort/filter/group
- [ ] Modal editing works
- [ ] Layout preference persists
- [ ] Command bar actions work
- [ ] Keyboard shortcuts work
