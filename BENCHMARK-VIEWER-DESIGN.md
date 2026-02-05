# BenchmarkViewer v2.2.x Design Document

**Version:** 2.2.x (Vue 2.7 + Bootstrap 4.6)
**Reference Implementation:** v2.3.0 (Vue 3 + TypeScript)
**Date:** 2025-02-05

## Table of Contents
- [Executive Summary](#executive-summary)
- [Architecture Overview](#architecture-overview)
- [v2.3.0 Analysis](#v230-analysis)
- [v2.2.x Design](#v22x-design)
- [Data Flow](#data-flow)
- [Component Specifications](#component-specifications)
- [Implementation Plan](#implementation-plan)

---

## Executive Summary

This document provides a complete design for backporting the v2.3.0 BenchmarkViewer pattern to v2.2.x. The v2.3.0 implementation uses TypeScript adapters to normalize STIG and SRG data into a unified interface, allowing shared components for viewing benchmarks.

**Key Pattern:** Adapter → Unified Interface → Shared Components

**v2.2.x Constraints:**
- Vue 2.7 (no `<script setup>`, no TypeScript files)
- JavaScript instead of TypeScript (adapters as functions, not typed interfaces)
- RULE_TERM constants instead of hardcoded strings
- Existing useBenchmarkViewer composable (needs enhancement)

**Current State (v2.2.x):**
- ✅ Has BenchmarkViewer.vue wrapper
- ✅ Has useBenchmarkViewer composable with config-driven approach
- ✅ Has StigRuleList, StigRuleDetails, StigRuleOverview components
- ❌ Components are STIG-specific (hardcoded labels)
- ❌ No adapter layer to normalize data
- ❌ No support for SRG viewing
- ❌ No RULE_TERM integration

**Goal:** Reusable BenchmarkViewer that works for both STIGs and SRGs with shared components.

---

## Architecture Overview

### v2.3.0 Pattern (Vue 3 + TypeScript)

```
┌─────────────────────────────────────────────────────────────┐
│                    Page Component                            │
│  Stig.vue or Srg.vue - Minimal wrapper                       │
│  - Receives benchmark data from Rails (STIG or SRG)          │
│  - Applies adapter: stigToBenchmark() or srgToBenchmark()    │
│  - Passes unified IBenchmark to BenchmarkViewer              │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                   BenchmarkViewer.vue                        │
│  - Receives: type ('stig'|'srg'), benchmark (IBenchmark)     │
│  - Manages: selectedRule state, rule sorting/selection       │
│  - Renders: 3-column layout (List, Details, Overview)        │
│  - Passes: type + rule to child components                   │
└─────────────────────────────────────────────────────────────┘
                               │
                ┌──────────────┼──────────────┐
                ▼              ▼              ▼
         ┌──────────┐   ┌──────────┐   ┌──────────┐
         │ RuleList │   │  Rule    │   │  Rule    │
         │          │   │ Details  │   │ Overview │
         └──────────┘   └──────────┘   └──────────┘

         ALL components use:
         - type prop to customize labels ('stig' vs 'srg')
         - Unified IBenchmarkRule interface
         - Type-specific display logic (v-if="type === 'stig'")
```

### v2.2.x Pattern (Vue 2.7 + JavaScript)

```
┌─────────────────────────────────────────────────────────────┐
│                    Page Component                            │
│  Stig.vue or Srg.vue - Minimal wrapper                       │
│  - Receives benchmark data from Rails (STIG or SRG)          │
│  - Applies adapter: stigToBenchmark() or srgToBenchmark()    │
│  - Passes unified benchmark to BenchmarkViewer               │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                   BenchmarkViewer.vue                        │
│  - Uses: useBenchmarkViewer composable (enhanced)            │
│  - Receives: type ('stig'|'srg'), benchmark (adapted)        │
│  - State: selectedRule, items, filteredItems                 │
│  - Renders: 3-column layout (List, Details, Overview)        │
│  - Passes: type + rule to shared components                  │
└─────────────────────────────────────────────────────────────┘
                               │
                ┌──────────────┼──────────────┐
                ▼              ▼              ▼
         ┌──────────┐   ┌──────────┐   ┌──────────┐
         │ RuleList │   │  Rule    │   │  Rule    │
         │          │   │ Details  │   │ Overview │
         └──────────┘   └──────────┘   └──────────┘

         ALL components use:
         - type prop to customize labels
         - RULE_TERM constants for terminology
         - Computed properties for type-specific display
```

---

## v2.3.0 Analysis

### Data Normalization (benchmark.ts)

The key insight: STIGs and SRGs have nearly identical structures but different field names.

**STIG Schema:**
```javascript
{
  id: number,
  stig_id: string,      // benchmark_id
  title: string,
  name: string,
  version: string,
  benchmark_date: string, // date
  description: string,
  stig_rules: [         // rules
    {
      id: number,
      rule_id: string,
      version: string,  // STIG ID
      title: string,
      rule_severity: string,
      vuln_id: string,  // STIG-specific
      srg_id: string,   // STIG-specific
      stig_id: number,  // foreign key
      disa_rule_descriptions_attributes: [...],
      checks_attributes: [...]
    }
  ]
}
```

**SRG Schema:**
```javascript
{
  id: number,
  srg_id: string,       // benchmark_id
  title: string,
  name: string,
  version: string,
  release_date: string, // date
  srg_rules: [          // rules
    {
      id: number,
      rule_id: string,
      version: string,
      title: string,
      rule_severity: string,
      security_requirements_guide_id: number, // foreign key
      disa_rule_descriptions_attributes: [...],
      checks_attributes: [...]
    }
  ]
}
```

**Unified Interface (IBenchmark):**
```javascript
{
  id: number,
  benchmark_id: string,  // stig_id OR srg_id
  title: string,
  name: string,
  version: string,
  date: string,          // benchmark_date OR release_date
  description: string,
  rules: [               // stig_rules OR srg_rules (normalized)
    {
      id: number,
      rule_id: string,
      version: string,
      title: string,
      rule_severity: string,
      // STIG-specific (optional)
      vuln_id: string,
      srg_id: string,
      stig_id: number,
      // SRG-specific (optional)
      security_requirements_guide_id: number,
      // Shared
      disa_rule_descriptions_attributes: [...],
      checks_attributes: [...]
    }
  ]
}
```

### Adapter Functions (benchmark.ts)

**stigToBenchmark:**
```javascript
export function stigToBenchmark(stig) {
  return {
    id: stig.id,
    benchmark_id: stig.stig_id,
    title: stig.title,
    name: stig.name,
    version: stig.version,
    date: stig.benchmark_date,
    description: stig.description,
    rules: stig.stig_rules?.map(stigRuleToBenchmarkRule)
  };
}
```

**srgToBenchmark:**
```javascript
export function srgToBenchmark(srg) {
  return {
    id: srg.id,
    benchmark_id: srg.srg_id,
    title: srg.title,
    name: srg.name,
    version: srg.version,
    date: srg.release_date,
    rules: srg.srg_rules?.map(srgRuleToBenchmarkRule)
  };
}
```

**Key Insight:** Rules are 95% identical. The adapters just normalize field names.

### Component Type Switching (RuleList.vue)

Components use `type` prop to switch labels:

```vue
<template>
  <input
    :placeholder="`Search by ${type === 'stig' ? 'STIG ID or SRG ID' : 'Rule ID or Version'}`"
  />
</template>

<script setup>
const fieldOptions = computed(() => [
  { value: 'rule_id', text: props.type === 'stig' ? 'SRG ID' : 'Rule ID' },
  { value: 'version', text: props.type === 'stig' ? 'STIG ID' : 'Version' }
]);
</script>
```

**STIG-specific content:**
```vue
<!-- Only render for STIGs -->
<li v-if="type === 'stig' && rule.vuln_id" class="list-group-item">
  <strong>Vuln ID</strong>: {{ rule.vuln_id }}
</li>
```

### State Management (BenchmarkViewer.vue)

State management is simple - no composable needed in v2.3.0:

```javascript
// Selected rule state
const selectedRule = ref(null);

// Sort rules and select first one on mount
const sortedRules = computed(() => {
  if (!props.benchmark.rules) return [];
  return [...props.benchmark.rules].sort((a, b) =>
    a.rule_id.localeCompare(b.rule_id)
  );
});

// Select initial rule
watch(() => sortedRules.value, (rules) => {
  if (rules.length > 0 && !selectedRule.value) {
    selectedRule.value = rules[0];
  }
}, { immediate: true });

// Handle rule selection from list
function onRuleSelected(rule) {
  selectedRule.value = rule;
}
```

**No composable needed** because:
- State is just `selectedRule` (single ref)
- Sorting is a computed property
- Selection is a simple event handler

The v2.2.x `useBenchmarkViewer` composable is **over-engineered** for this use case. We can simplify.

---

## v2.2.x Design

### Adapter Layer (app/javascript/adapters/benchmark.js)

**NEW FILE** - Normalizes STIG/SRG data to unified format.

```javascript
/**
 * Benchmark Adapters
 *
 * Normalize STIG and SRG data into unified benchmark format.
 * Adapts different field names to common interface.
 */

/**
 * Convert STIG to unified benchmark format
 * @param {Object} stig - STIG object from API
 * @returns {Object} Unified benchmark
 */
export function stigToBenchmark(stig) {
  return {
    id: stig.id,
    benchmark_id: stig.stig_id,
    title: stig.title,
    name: stig.name,
    version: stig.version,
    date: stig.benchmark_date,
    description: stig.description,
    created_at: stig.created_at,
    updated_at: stig.updated_at,
    rules: stig.stig_rules?.map(stigRuleToBenchmarkRule) || []
  };
}

/**
 * Convert SRG to unified benchmark format
 * @param {Object} srg - SRG object from API
 * @returns {Object} Unified benchmark
 */
export function srgToBenchmark(srg) {
  return {
    id: srg.id,
    benchmark_id: srg.srg_id,
    title: srg.title,
    name: srg.name,
    version: srg.version,
    date: srg.release_date,
    created_at: srg.created_at,
    updated_at: srg.updated_at,
    rules: srg.srg_rules?.map(srgRuleToBenchmarkRule) || []
  };
}

/**
 * Convert STIG rule to unified benchmark rule format
 * @param {Object} rule - STIG rule from API
 * @returns {Object} Normalized rule
 */
export function stigRuleToBenchmarkRule(rule) {
  return {
    id: rule.id,
    rule_id: rule.rule_id || '',
    version: rule.version,
    title: rule.title,
    rule_severity: rule.rule_severity || 'medium',
    rule_weight: rule.rule_weight,
    ident: rule.ident,
    ident_system: rule.ident_system,
    legacy_ids: rule.legacy_ids,
    fixtext: rule.fixtext,
    fixtext_fixref: rule.fixtext_fixref,
    fix_id: rule.fix_id,
    nist_control_family: rule.nist_control_family,
    // STIG-specific fields
    vuln_id: rule.vuln_id,
    srg_id: rule.srg_id,
    stig_id: rule.stig_id,
    vendor_comments: rule.vendor_comments,
    // Nested attributes (pass through)
    checks_attributes: rule.checks_attributes,
    disa_rule_descriptions_attributes: rule.disa_rule_descriptions_attributes
  };
}

/**
 * Convert SRG rule to unified benchmark rule format
 * @param {Object} rule - SRG rule from API
 * @returns {Object} Normalized rule
 */
export function srgRuleToBenchmarkRule(rule) {
  return {
    id: rule.id,
    rule_id: rule.rule_id,
    version: rule.version,
    title: rule.title,
    rule_severity: rule.rule_severity,
    rule_weight: rule.rule_weight,
    ident: rule.ident,
    ident_system: rule.ident_system,
    legacy_ids: rule.legacy_ids,
    fixtext: rule.fixtext,
    fixtext_fixref: rule.fixtext_fixref,
    fix_id: rule.fix_id,
    nist_control_family: rule.nist_control_family,
    // SRG-specific fields
    security_requirements_guide_id: rule.security_requirements_guide_id,
    // Nested attributes (pass through)
    checks_attributes: rule.checks_attributes,
    disa_rule_descriptions_attributes: rule.disa_rule_descriptions_attributes
  };
}
```

### Utilities (app/javascript/utils/ident-parser.js)

**NEW FILE** - Port from v2.3.0 (TypeScript → JavaScript).

```javascript
/**
 * Ident Parser Utility
 *
 * Parses XCCDF ident strings into categorized arrays for display.
 *
 * XCCDF idents include multiple identifier types:
 * - CCIs (CCI-000000): DISA Control Correlation Identifiers
 * - CIS Controls v7 (7:X.Y): CIS Critical Security Controls v7
 * - CIS Controls v8 (8:X.Y): CIS Critical Security Controls v8
 * - MITRE ATT&CK Techniques (T0000): Attack techniques
 * - MITRE ATT&CK Tactics (TA0000): Attack tactics
 * - MITRE ATT&CK Mitigations (M0000): Mitigations
 */

/**
 * Parse a comma-separated ident string into categorized arrays
 *
 * @param {string|null|undefined} ident - Comma-separated string of identifiers
 * @returns {Object} Categorized ident arrays
 *
 * @example
 * const parsed = parseIdents('CCI-000366, 8:3.14, 7:14.9, T1565, TA0001, M1022')
 * // Returns:
 * // {
 * //   ccis: ['CCI-000366'],
 * //   cisV7: ['7:14.9'],
 * //   cisV8: ['8:3.14'],
 * //   mitreTechniques: ['T1565'],
 * //   mitreTactics: ['TA0001'],
 * //   mitreMitigations: ['M1022'],
 * //   other: []
 * // }
 */
export function parseIdents(ident) {
  const result = {
    ccis: [],
    cisV7: [],
    cisV8: [],
    mitreTechniques: [],
    mitreTactics: [],
    mitreMitigations: [],
    other: []
  };

  if (!ident) return result;

  const idents = ident.split(/,\s*/);

  for (const item of idents) {
    const trimmed = item.trim();
    if (!trimmed) continue;

    if (trimmed.startsWith('CCI-')) {
      result.ccis.push(trimmed);
    } else if (trimmed.startsWith('7:')) {
      result.cisV7.push(trimmed);
    } else if (trimmed.startsWith('8:')) {
      result.cisV8.push(trimmed);
    } else if (/^T\d/.test(trimmed)) {
      result.mitreTechniques.push(trimmed);
    } else if (/^TA\d/.test(trimmed)) {
      result.mitreTactics.push(trimmed);
    } else if (/^M\d/.test(trimmed)) {
      result.mitreMitigations.push(trimmed);
    } else {
      result.other.push(trimmed);
    }
  }

  return result;
}

/**
 * Check if parsed idents has any CIS Controls data
 * @param {Object} parsed - Parsed idents object
 * @returns {boolean}
 */
export function hasCisControls(parsed) {
  return parsed.cisV7.length > 0 || parsed.cisV8.length > 0;
}

/**
 * Check if parsed idents has any MITRE ATT&CK data
 * @param {Object} parsed - Parsed idents object
 * @returns {boolean}
 */
export function hasMitreData(parsed) {
  return parsed.mitreTechniques.length > 0
    || parsed.mitreTactics.length > 0
    || parsed.mitreMitigations.length > 0;
}

/**
 * Format CIS Control for display (strips version prefix)
 * @param {string} control - CIS control string (e.g., '8:3.14')
 * @returns {string} Formatted control (e.g., '3.14')
 * @example formatCisControl('8:3.14') => '3.14'
 */
export function formatCisControl(control) {
  return control.replace(/^\d:/, '');
}
```

### Shared Components

#### RuleList.vue (RENAME from StigRuleList.vue)

**Location:** `app/javascript/components/shared/RuleList.vue`

**Changes from StigRuleList:**
1. Add `type` prop
2. Use RULE_TERM constants
3. Computed properties for type-specific labels
4. Remove hardcoded "STIG ID" / "SRG ID" labels

```vue
<template>
  <div class="p-3">
    <!-- Filter Section -->
    <div class="mb-3">
      <h5 class="card-title">Filter & Search</h5>
      <div class="input-group">
        <p class="card-text">
          <strong>Search</strong><br />
          <input
            v-model="searchText"
            type="text"
            class="form-control"
            :placeholder="searchPlaceholder"
          /><br />
          <strong>Filter by Severity</strong><br />
          <button class="btn btn-danger mb-2" @click="setSeverity('high')">
            High <span class="badge badge-light">{{ high_count }}</span>
          </button>
          <button class="btn btn-warning mb-2" @click="setSeverity('medium')">
            Medium <span class="badge badge-light">{{ medium_count }}</span>
          </button>
          <button class="btn btn-success mb-2" @click="setSeverity('low')">
            Low <span class="badge badge-light">{{ low_count }}</span>
          </button>
          <button class="btn btn-info mb-2" @click="setSeverity('')">
            All <span class="badge badge-light">{{ rules.length }}</span>
          </button>
        </p>
      </div>
    </div>

    <!-- Table of Rules -->
    <div class="mt-3" style="max-height: 700px; overflow-y: auto">
      <h5 class="card-title">{{ RULE_TERM.plural }}</h5>
      <table class="table table-hover">
        <thead>
          <tr>
            <th class="d-flex">
              <b-form-select v-model="field" :options="fieldOptions" />
              <b-icon
                v-if="sortOrder === 'asc'"
                icon="arrow-down-circle"
                aria-hidden="true"
                @click="sortOrder = 'desc'"
              />
              <b-icon
                v-if="sortOrder === 'desc'"
                icon="arrow-up-circle"
                aria-hidden="true"
                @click="sortOrder = 'asc'"
              />
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="rule in sortedRules"
            :key="rule.id"
            :class="selectedRule && selectedRule.id === rule.id ? 'bg-secondary text-white' : ''"
            @click="selectRule(rule)"
          >
            <td>{{ displayField(rule) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script>
import { RULE_TERM } from '../../constants/terminology';

export default {
  name: 'RuleList',
  props: {
    type: {
      type: String,
      required: true,
      validator: (value) => ['stig', 'srg'].includes(value)
    },
    rules: {
      type: Array,
      required: true
    },
    initialSelectedRule: {
      type: Object,
      required: true
    }
  },
  data() {
    return {
      RULE_TERM,
      searchText: '',
      selectedSeverity: '',
      low_count: this.filterBySeverity('low').length,
      medium_count: this.filterBySeverity('medium').length,
      high_count: this.filterBySeverity('high').length,
      field: 'rule_id',
      sortOrder: 'asc',
      selectedRule: this.initialSelectedRule
    };
  },
  computed: {
    searchPlaceholder() {
      return this.type === 'stig'
        ? 'Search by STIG ID or SRG ID'
        : 'Search by Rule ID or Version';
    },
    fieldOptions() {
      return [
        {
          value: 'rule_id',
          text: this.type === 'stig' ? 'SRG ID' : 'Rule ID'
        },
        {
          value: 'version',
          text: this.type === 'stig' ? 'STIG ID' : 'Version'
        }
      ];
    },
    filteredRules() {
      if (this.searchText) {
        return this.rules.filter((rule) => {
          const searchText = this.searchText.toLowerCase();
          return (
            rule.rule_id.toLowerCase().includes(searchText) ||
            rule.version.toLowerCase().includes(searchText)
          );
        });
      } else if (this.selectedSeverity) {
        return this.filterBySeverity(this.selectedSeverity);
      } else {
        return this.rules;
      }
    },
    sortedRules() {
      const rules = this.filteredRules;
      return rules.sort((a, b) => {
        const aVal = this.field === 'rule_id' ? a.rule_id : a.version;
        const bVal = this.field === 'rule_id' ? b.rule_id : b.version;
        const comparison = aVal.localeCompare(bVal);
        return this.sortOrder === 'asc' ? comparison : -comparison;
      });
    }
  },
  methods: {
    setSeverity(severity) {
      this.selectedSeverity = severity;
    },
    filterBySeverity(severity) {
      return this.rules.filter((rule) => rule.rule_severity === severity);
    },
    selectRule(rule) {
      this.selectedRule = rule;
      this.$emit('rule-selected', rule);
    },
    displayField(rule) {
      return this.field === 'rule_id' ? rule.rule_id : rule.version;
    }
  }
};
</script>
```

#### RuleDetails.vue (RENAME from StigRuleDetails.vue)

**Location:** `app/javascript/components/shared/RuleDetails.vue`

**Changes from StigRuleDetails:**
1. Add `type` prop (for future expansion)
2. Use selectedRule prop name consistently
3. No hardcoded changes needed (already generic)

```vue
<template>
  <div class="card h-100">
    <div class="card-header">
      <h5 class="card-title">{{ selectedRule.title }}</h5>
    </div>
    <div class="card-body">
      <b-form>
        <!-- Vulnerability Discussion -->
        <DisaRuleDescriptionForm
          :rule="selectedRule"
          :index="0"
          :description="selectedRule.disa_rule_descriptions_attributes[0]"
          :disabled="true"
          :fields="disaDescriptionFormFields"
        />

        <!-- Check Content -->
        <CheckForm
          :rule="selectedRule"
          :index="0"
          :disabled="true"
          :fields="checkFormFields"
        />

        <!-- Fix Text -->
        <b-form-group>
          <label :for="`rule-fixtext-${selectedRule.id}`">
            Fix
            <b-icon
              v-b-tooltip.hover.html="
                'Describe how to correctly configure the requirement to remediate the system vulnerability'
              "
              icon="info-circle"
              aria-hidden="true"
            />
          </label>
          <b-form-textarea
            :id="`rule-fixtext-${selectedRule.id}`"
            :value="selectedRule.fixtext"
            placeholder=""
            :disabled="true"
            rows="1"
            max-rows="99"
          />
        </b-form-group>

        <!-- Vendor Comment (if present) -->
        <b-form-group v-if="selectedRule.vendor_comments">
          <label :for="`rule-vendor-comments-${selectedRule.id}`">
            Vendor Comments
            <b-icon
              v-b-tooltip.hover.html="
                'Provide context to a reviewing authority; not a published field'
              "
              icon="info-circle"
              aria-hidden="true"
            />
          </label>
          <b-form-textarea
            :id="`rule-vendor-comments-${selectedRule.id}`"
            :value="selectedRule.vendor_comments"
            placeholder=""
            :disabled="true"
            rows="1"
            max-rows="99"
          />
        </b-form-group>
      </b-form>
    </div>
  </div>
</template>

<script>
import DisaRuleDescriptionForm from '../rules/forms/DisaRuleDescriptionForm';
import CheckForm from '../rules/forms/CheckForm';

export default {
  name: 'RuleDetails',
  components: { DisaRuleDescriptionForm, CheckForm },
  props: {
    type: {
      type: String,
      required: true,
      validator: (value) => ['stig', 'srg'].includes(value)
    },
    selectedRule: {
      type: Object,
      required: true
    }
  },
  computed: {
    disaDescriptionFormFields() {
      return { displayed: ['vuln_discussion'], disabled: [] };
    },
    checkFormFields() {
      return {
        displayed: ['content'],
        disabled: []
      };
    }
  }
};
</script>
```

#### RuleOverview.vue (RENAME from StigRuleOverview.vue)

**Location:** `app/javascript/components/shared/RuleOverview.vue`

**Changes from StigRuleOverview:**
1. Add `type` prop
2. Use RULE_TERM constants
3. Conditional rendering for STIG-specific fields
4. Add CIS Controls and MITRE ATT&CK parsing

```vue
<template>
  <div class="card h-100 w-100">
    <div class="card-header">
      <h5 class="card-title">{{ RULE_TERM.singular }} Overview</h5>
    </div>
    <div class="card-body">
      <ul class="list-group list-group-flush">
        <!-- STIG-specific: Vuln ID -->
        <li v-if="type === 'stig' && selectedRule.vuln_id" class="list-group-item">
          <strong>Vuln ID</strong>: {{ selectedRule.vuln_id }}
        </li>

        <!-- Rule ID -->
        <li class="list-group-item">
          <strong>Rule ID</strong>: {{ selectedRule.rule_id }}
        </li>

        <!-- Version / STIG ID -->
        <li class="list-group-item">
          <strong>{{ versionLabel }}</strong>: {{ selectedRule.version }}
        </li>

        <!-- STIG-specific: SRG ID -->
        <li v-if="type === 'stig' && selectedRule.srg_id" class="list-group-item">
          <strong>SRG ID</strong>: {{ selectedRule.srg_id }}
        </li>

        <!-- Severity -->
        <li class="list-group-item">
          <strong>Severity</strong>:
          <span class="badge" :class="severityBgColor">
            {{ selectedRule.rule_severity }}
          </span>
        </li>

        <!-- Legacy IDs -->
        <li v-if="selectedRule.legacy_ids" class="list-group-item">
          <strong>Legacy IDs</strong>: {{ selectedRule.legacy_ids }}
        </li>

        <!-- CCIs (DISA Control Correlation Identifiers) -->
        <li v-if="parsedIdents.ccis.length > 0" class="list-group-item">
          <strong>CCI</strong>: {{ parsedIdents.ccis.join(', ') }}
        </li>

        <!-- NIST Control Family / IA Control -->
        <li v-if="selectedRule.nist_control_family" class="list-group-item">
          <strong>IA Control</strong>: {{ selectedRule.nist_control_family }}
        </li>

        <!-- CIS Controls v8 -->
        <li v-if="parsedIdents.cisV8.length > 0" class="list-group-item">
          <strong>CIS Controls v8</strong>:
          <span v-for="(control, idx) in parsedIdents.cisV8" :key="control">
            <a
              href="https://www.cisecurity.org/controls/v8"
              target="_blank"
              rel="noopener noreferrer"
              class="text-decoration-none"
            >{{ formatCisControl(control) }}</a>
            <span v-if="idx < parsedIdents.cisV8.length - 1">, </span>
          </span>
        </li>

        <!-- CIS Controls v7 -->
        <li v-if="parsedIdents.cisV7.length > 0" class="list-group-item">
          <strong>CIS Controls v7</strong>:
          <span v-for="(control, idx) in parsedIdents.cisV7" :key="control">
            <a
              href="https://www.cisecurity.org/controls/v7"
              target="_blank"
              rel="noopener noreferrer"
              class="text-decoration-none"
            >{{ formatCisControl(control) }}</a>
            <span v-if="idx < parsedIdents.cisV7.length - 1">, </span>
          </span>
        </li>

        <!-- MITRE ATT&CK Techniques -->
        <li v-if="parsedIdents.mitreTechniques.length > 0" class="list-group-item">
          <strong>ATT&CK Techniques</strong>:
          <span v-for="(tech, idx) in parsedIdents.mitreTechniques" :key="tech">
            <a
              :href="`https://attack.mitre.org/techniques/${tech.replace('.', '/')}`"
              target="_blank"
              rel="noopener noreferrer"
              class="text-decoration-none"
            >{{ tech }}</a>
            <span v-if="idx < parsedIdents.mitreTechniques.length - 1">, </span>
          </span>
        </li>

        <!-- MITRE ATT&CK Tactics -->
        <li v-if="parsedIdents.mitreTactics.length > 0" class="list-group-item">
          <strong>ATT&CK Tactics</strong>:
          <span v-for="(tactic, idx) in parsedIdents.mitreTactics" :key="tactic">
            <a
              :href="`https://attack.mitre.org/tactics/${tactic}`"
              target="_blank"
              rel="noopener noreferrer"
              class="text-decoration-none"
            >{{ tactic }}</a>
            <span v-if="idx < parsedIdents.mitreTactics.length - 1">, </span>
          </span>
        </li>

        <!-- MITRE ATT&CK Mitigations -->
        <li v-if="parsedIdents.mitreMitigations.length > 0" class="list-group-item">
          <strong>ATT&CK Mitigations</strong>:
          <span v-for="(mit, idx) in parsedIdents.mitreMitigations" :key="mit">
            <a
              :href="`https://attack.mitre.org/mitigations/${mit}`"
              target="_blank"
              rel="noopener noreferrer"
              class="text-decoration-none"
            >{{ mit }}</a>
            <span v-if="idx < parsedIdents.mitreMitigations.length - 1">, </span>
          </span>
        </li>

        <!-- Other/Unknown Idents (fallback) -->
        <li v-if="parsedIdents.other.length > 0" class="list-group-item">
          <strong>Other</strong>: {{ parsedIdents.other.join(', ') }}
        </li>

        <!-- Status (if present) -->
        <li v-if="selectedRule.status" class="list-group-item">
          <strong>Status</strong>: {{ selectedRule.status }}
        </li>
      </ul>
    </div>
  </div>
</template>

<script>
import { RULE_TERM } from '../../constants/terminology';
import { parseIdents, formatCisControl } from '../../utils/ident-parser';

export default {
  name: 'RuleOverview',
  props: {
    type: {
      type: String,
      required: true,
      validator: (value) => ['stig', 'srg'].includes(value)
    },
    selectedRule: {
      type: Object,
      required: true
    }
  },
  data() {
    return {
      RULE_TERM
    };
  },
  computed: {
    versionLabel() {
      return this.type === 'stig' ? 'STIG ID' : 'Version';
    },
    severityBgColor() {
      const severity = this.selectedRule.rule_severity;
      if (severity === 'high') {
        return 'bg-danger';
      } else if (severity === 'medium') {
        return 'bg-warning text-dark';
      } else {
        return 'bg-success';
      }
    },
    parsedIdents() {
      return parseIdents(this.selectedRule.ident);
    }
  },
  methods: {
    formatCisControl
  }
};
</script>
```

### BenchmarkViewer.vue (UPDATE existing)

**Location:** `app/javascript/components/shared/BenchmarkViewer.vue`

**Changes:**
1. Remove useBenchmarkViewer composable (over-engineered)
2. Add simple state management (selectedRule ref)
3. Use shared RuleList/RuleDetails/RuleOverview components
4. Pass `type` prop to all child components

```vue
<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <!-- Command Bar -->
    <BaseCommandBar>
      <template #left>
        <b-button
          variant="outline-secondary"
          size="sm"
          :href="listPath"
        >
          <b-icon icon="arrow-left" /> Back to {{ typeLabel }}s
        </b-button>
        <b-button
          variant="outline-secondary"
          size="sm"
          class="ml-2"
          @click="openExportModal"
        >
          <b-icon icon="download" /> Download
        </b-button>
      </template>
      <template #right>
        <!-- No panels for viewer page -->
      </template>
    </BaseCommandBar>

    <!-- Three-Column Layout -->
    <b-row>
      <!-- Left: Rule List -->
      <b-col md="3">
        <RuleList
          :type="type"
          :rules="sortedRules"
          :initial-selected-rule="selectedRule"
          @rule-selected="selectRule"
        />
      </b-col>

      <!-- Middle: Rule Details -->
      <b-col md="6">
        <RuleDetails
          v-if="selectedRule"
          :type="type"
          :selected-rule="selectedRule"
        />
        <div v-else class="alert alert-info">
          Select a {{ RULE_TERM.singular.toLowerCase() }} to view details
        </div>
      </b-col>

      <!-- Right: Rule Overview -->
      <b-col md="3">
        <RuleOverview
          v-if="selectedRule"
          :type="type"
          :selected-rule="selectedRule"
        />
      </b-col>
    </b-row>

    <!-- Export Modal -->
    <ExportModal
      v-if="showExportModal"
      v-model="showExportModal"
      :components="[benchmark]"
      @export="handleExport"
      @cancel="showExportModal = false"
    />
  </div>
</template>

<script>
import axios from 'axios';
import BaseCommandBar from './BaseCommandBar.vue';
import ExportModal from './ExportModal.vue';
import RuleList from './RuleList.vue';
import RuleDetails from './RuleDetails.vue';
import RuleOverview from './RuleOverview.vue';
import AlertMixinVue from '../../mixins/AlertMixin.vue';
import { RULE_TERM } from '../../constants/terminology';

export default {
  name: 'BenchmarkViewer',
  components: {
    BaseCommandBar,
    ExportModal,
    RuleList,
    RuleDetails,
    RuleOverview
  },
  mixins: [AlertMixinVue],
  props: {
    benchmark: {
      type: Object,
      required: true
    },
    type: {
      type: String,
      required: true,
      validator: (value) => ['stig', 'srg'].includes(value)
    }
  },
  data() {
    return {
      RULE_TERM,
      selectedRule: null,
      showExportModal: false
    };
  },
  computed: {
    breadcrumbs() {
      return [
        { text: this.typeLabel + 's', href: this.listPath },
        { text: `${this.benchmark.title} ${this.benchmark.version || ''}`, active: true }
      ];
    },
    typeLabel() {
      const labels = {
        stig: 'STIG',
        srg: 'SRG'
      };
      return labels[this.type] || 'Benchmark';
    },
    listPath() {
      const paths = {
        stig: '/stigs',
        srg: '/srgs'
      };
      return paths[this.type] || '/';
    },
    sortedRules() {
      if (!this.benchmark.rules) return [];
      return [...this.benchmark.rules].sort((a, b) =>
        a.rule_id.localeCompare(b.rule_id)
      );
    }
  },
  watch: {
    sortedRules: {
      handler(rules) {
        // Select first rule on mount
        if (rules.length > 0 && !this.selectedRule) {
          this.selectedRule = rules[0];
        }
      },
      immediate: true
    }
  },
  methods: {
    selectRule(rule) {
      this.selectedRule = rule;
    },
    openExportModal() {
      this.showExportModal = true;
    },
    handleExport({ type }) {
      const benchmarkType = this.type === 'srg' ? 'srgs' : 'stigs';
      axios
        .get(`/${benchmarkType}/${this.benchmark.id}/export/${type}`)
        .then(() => {
          window.open(`/${benchmarkType}/${this.benchmark.id}/export/${type}`);
        })
        .catch(this.alertOrNotifyResponse);
    }
  }
};
</script>
```

### Page Wrappers

#### Stig.vue (UPDATE existing)

**Location:** `app/javascript/components/stigs/Stig.vue`

**Changes:**
1. Import stigToBenchmark adapter
2. Apply adapter before passing to BenchmarkViewer

```vue
<template>
  <BenchmarkViewer :benchmark="adaptedStig" type="stig" />
</template>

<script>
import BenchmarkViewer from '../shared/BenchmarkViewer.vue';
import { stigToBenchmark } from '../../adapters/benchmark';

export default {
  name: 'Stig',
  components: { BenchmarkViewer },
  props: {
    stig: {
      type: Object,
      required: true
    }
  },
  computed: {
    adaptedStig() {
      return stigToBenchmark(this.stig);
    }
  }
};
</script>
```

#### Srg.vue (NEW FILE)

**Location:** `app/javascript/components/srgs/Srg.vue`

**Pattern:** Identical to Stig.vue but for SRGs.

```vue
<template>
  <BenchmarkViewer :benchmark="adaptedSrg" type="srg" />
</template>

<script>
import BenchmarkViewer from '../shared/BenchmarkViewer.vue';
import { srgToBenchmark } from '../../adapters/benchmark';

export default {
  name: 'Srg',
  components: { BenchmarkViewer },
  props: {
    srg: {
      type: Object,
      required: true
    }
  },
  computed: {
    adaptedSrg() {
      return srgToBenchmark(this.srg);
    }
  }
};
</script>
```

---

## Data Flow

### STIG Viewing

```
1. User visits /stigs/:id
   ↓
2. Rails renders views/stigs/show.html.haml
   ↓
3. HAML passes @stig (with stig_rules) to Stig.vue
   ↓
4. Stig.vue applies stigToBenchmark adapter:
   - stig_id → benchmark_id
   - benchmark_date → date
   - stig_rules → rules (mapped with stigRuleToBenchmarkRule)
   ↓
5. Passes adapted benchmark + type='stig' to BenchmarkViewer
   ↓
6. BenchmarkViewer:
   - Sorts rules by rule_id
   - Selects first rule
   - Renders RuleList, RuleDetails, RuleOverview with type='stig'
   ↓
7. Components use type prop to customize:
   - Labels: "SRG ID" vs "Rule ID"
   - Conditional fields: vuln_id, srg_id (STIG-only)
```

### SRG Viewing

```
1. User visits /srgs/:id
   ↓
2. Rails renders views/srgs/show.html.haml
   ↓
3. HAML passes @srg (with srg_rules) to Srg.vue
   ↓
4. Srg.vue applies srgToBenchmark adapter:
   - srg_id → benchmark_id
   - release_date → date
   - srg_rules → rules (mapped with srgRuleToBenchmarkRule)
   ↓
5. Passes adapted benchmark + type='srg' to BenchmarkViewer
   ↓
6. BenchmarkViewer:
   - Sorts rules by rule_id
   - Selects first rule
   - Renders RuleList, RuleDetails, RuleOverview with type='srg'
   ↓
7. Components use type prop to customize:
   - Labels: "Rule ID", "Version"
   - Hides STIG-specific fields (vuln_id, srg_id)
```

---

## Component Specifications

### Props Interface

**BenchmarkViewer:**
- `benchmark` (Object, required) - Adapted benchmark data (unified format)
- `type` (String, required) - 'stig' | 'srg'

**RuleList, RuleDetails, RuleOverview:**
- `type` (String, required) - 'stig' | 'srg'
- `selectedRule` (Object, required) - Current rule from adapted benchmark

### Events

**RuleList:**
- `@rule-selected` - Emits selected rule object

### Terminology Integration

All components use `RULE_TERM` constants:

```javascript
import { RULE_TERM } from '../../constants/terminology';

// Usage in template:
<h5>{{ RULE_TERM.plural }}</h5>
<div>Select a {{ RULE_TERM.singular.toLowerCase() }} to view</div>
```

### Type-Specific Display

Components use computed properties and conditional rendering:

```vue
<script>
computed: {
  searchPlaceholder() {
    return this.type === 'stig'
      ? 'Search by STIG ID or SRG ID'
      : 'Search by Rule ID or Version';
  }
}
</script>

<template>
  <!-- STIG-specific field -->
  <li v-if="type === 'stig' && rule.vuln_id">
    <strong>Vuln ID</strong>: {{ rule.vuln_id }}
  </li>
</template>
```

---

## Implementation Plan

### Phase 1: Create Adapter Layer (TDD)

**Tests:** `app/javascript/__tests__/adapters/benchmark.spec.js`

1. **Test stigToBenchmark adapter:**
   ```javascript
   describe('stigToBenchmark', () => {
     it('normalizes stig_id to benchmark_id', () => {
       const stig = { stig_id: 'test-stig', /* ... */ };
       const result = stigToBenchmark(stig);
       expect(result.benchmark_id).toBe('test-stig');
     });

     it('normalizes benchmark_date to date', () => {
       const stig = { benchmark_date: '2024-01-01', /* ... */ };
       const result = stigToBenchmark(stig);
       expect(result.date).toBe('2024-01-01');
     });

     it('maps stig_rules to rules array', () => {
       const stig = {
         stig_rules: [{ rule_id: 'SRG-001', /* ... */ }],
         /* ... */
       };
       const result = stigToBenchmark(stig);
       expect(result.rules).toHaveLength(1);
       expect(result.rules[0].rule_id).toBe('SRG-001');
     });

     it('handles missing stig_rules gracefully', () => {
       const stig = { /* no stig_rules */ };
       const result = stigToBenchmark(stig);
       expect(result.rules).toEqual([]);
     });
   });
   ```

2. **Test srgToBenchmark adapter:**
   ```javascript
   describe('srgToBenchmark', () => {
     it('normalizes srg_id to benchmark_id', () => {
       const srg = { srg_id: 'test-srg', /* ... */ };
       const result = srgToBenchmark(srg);
       expect(result.benchmark_id).toBe('test-srg');
     });

     it('normalizes release_date to date', () => {
       const srg = { release_date: '2024-01-01', /* ... */ };
       const result = srgToBenchmark(srg);
       expect(result.date).toBe('2024-01-01');
     });

     it('maps srg_rules to rules array', () => {
       const srg = {
         srg_rules: [{ rule_id: 'SRG-001', /* ... */ }],
         /* ... */
       };
       const result = srgToBenchmark(srg);
       expect(result.rules).toHaveLength(1);
       expect(result.rules[0].rule_id).toBe('SRG-001');
     });
   });
   ```

3. **Test rule adapters:**
   ```javascript
   describe('stigRuleToBenchmarkRule', () => {
     it('preserves all common fields', () => {
       const rule = {
         id: 1,
         rule_id: 'SRG-001',
         version: 'V-001',
         title: 'Test Rule',
         rule_severity: 'high',
         /* ... */
       };
       const result = stigRuleToBenchmarkRule(rule);
       expect(result.id).toBe(1);
       expect(result.rule_id).toBe('SRG-001');
       expect(result.version).toBe('V-001');
     });

     it('preserves STIG-specific fields', () => {
       const rule = {
         vuln_id: 'V-001',
         srg_id: 'SRG-001',
         stig_id: 123,
         /* ... */
       };
       const result = stigRuleToBenchmarkRule(rule);
       expect(result.vuln_id).toBe('V-001');
       expect(result.srg_id).toBe('SRG-001');
       expect(result.stig_id).toBe(123);
     });
   });

   describe('srgRuleToBenchmarkRule', () => {
     it('preserves SRG-specific fields', () => {
       const rule = {
         security_requirements_guide_id: 456,
         /* ... */
       };
       const result = srgRuleToBenchmarkRule(rule);
       expect(result.security_requirements_guide_id).toBe(456);
     });
   });
   ```

4. **Implementation:**
   - Create `app/javascript/adapters/benchmark.js`
   - Implement stigToBenchmark, srgToBenchmark
   - Implement stigRuleToBenchmarkRule, srgRuleToBenchmarkRule
   - Run tests: `yarn test:unit adapters/benchmark.spec.js`
   - All tests pass ✓

### Phase 2: Create Utility Layer (TDD)

**Tests:** `app/javascript/__tests__/utils/ident-parser.spec.js`

1. **Test parseIdents utility:**
   ```javascript
   describe('parseIdents', () => {
     it('parses CCIs correctly', () => {
       const result = parseIdents('CCI-000366, CCI-001234');
       expect(result.ccis).toEqual(['CCI-000366', 'CCI-001234']);
     });

     it('parses CIS Controls v8', () => {
       const result = parseIdents('8:3.14, 8:5.1');
       expect(result.cisV8).toEqual(['8:3.14', '8:5.1']);
     });

     it('parses MITRE ATT&CK techniques', () => {
       const result = parseIdents('T1565, T1003.001');
       expect(result.mitreTechniques).toEqual(['T1565', 'T1003.001']);
     });

     it('handles null/undefined gracefully', () => {
       expect(parseIdents(null)).toEqual({
         ccis: [], cisV7: [], cisV8: [],
         mitreTechniques: [], mitreTactics: [], mitreMitigations: [],
         other: []
       });
     });

     it('parses mixed identifiers', () => {
       const result = parseIdents('CCI-000366, 8:3.14, T1565, TA0001, M1022');
       expect(result.ccis).toEqual(['CCI-000366']);
       expect(result.cisV8).toEqual(['8:3.14']);
       expect(result.mitreTechniques).toEqual(['T1565']);
       expect(result.mitreTactics).toEqual(['TA0001']);
       expect(result.mitreMitigations).toEqual(['M1022']);
     });
   });

   describe('formatCisControl', () => {
     it('strips version prefix from CIS control', () => {
       expect(formatCisControl('8:3.14')).toBe('3.14');
       expect(formatCisControl('7:14.9')).toBe('14.9');
     });
   });
   ```

2. **Implementation:**
   - Create `app/javascript/utils/ident-parser.js`
   - Port TypeScript implementation to JavaScript
   - Run tests: `yarn test:unit utils/ident-parser.spec.js`
   - All tests pass ✓

### Phase 3: Refactor Shared Components (TDD)

**Strategy:** Rename and enhance existing STIG components.

#### 3.1: RuleList Component

**Tests:** `app/javascript/__tests__/components/shared/RuleList.spec.js`

1. **Test type-specific behavior:**
   ```javascript
   import { mount } from '@vue/test-utils';
   import RuleList from '@/components/shared/RuleList.vue';

   describe('RuleList', () => {
     const mockRules = [
       { id: 1, rule_id: 'SRG-001', version: 'V-001', title: 'Test', rule_severity: 'high' },
       { id: 2, rule_id: 'SRG-002', version: 'V-002', title: 'Test 2', rule_severity: 'low' }
     ];

     describe('STIG mode', () => {
       it('displays STIG-specific placeholder', () => {
         const wrapper = mount(RuleList, {
           propsData: {
             type: 'stig',
             rules: mockRules,
             initialSelectedRule: mockRules[0]
           }
         });
         expect(wrapper.find('input').attributes('placeholder'))
           .toBe('Search by STIG ID or SRG ID');
       });

       it('displays STIG-specific field options', () => {
         const wrapper = mount(RuleList, {
           propsData: { type: 'stig', rules: mockRules, initialSelectedRule: mockRules[0] }
         });
         expect(wrapper.vm.fieldOptions[0].text).toBe('SRG ID');
         expect(wrapper.vm.fieldOptions[1].text).toBe('STIG ID');
       });
     });

     describe('SRG mode', () => {
       it('displays SRG-specific placeholder', () => {
         const wrapper = mount(RuleList, {
           propsData: {
             type: 'srg',
             rules: mockRules,
             initialSelectedRule: mockRules[0]
           }
         });
         expect(wrapper.find('input').attributes('placeholder'))
           .toBe('Search by Rule ID or Version');
       });

       it('displays SRG-specific field options', () => {
         const wrapper = mount(RuleList, {
           propsData: { type: 'srg', rules: mockRules, initialSelectedRule: mockRules[0] }
         });
         expect(wrapper.vm.fieldOptions[0].text).toBe('Rule ID');
         expect(wrapper.vm.fieldOptions[1].text).toBe('Version');
       });
     });

     it('emits rule-selected event when rule clicked', () => {
       const wrapper = mount(RuleList, {
         propsData: { type: 'stig', rules: mockRules, initialSelectedRule: mockRules[0] }
       });
       wrapper.findAll('tr').at(1).trigger('click');
       expect(wrapper.emitted('rule-selected')[0][0]).toEqual(mockRules[1]);
     });
   });
   ```

2. **Implementation:**
   - Rename `app/javascript/components/stigs/StigRuleList.vue` → `app/javascript/components/shared/RuleList.vue`
   - Add `type` prop
   - Add computed properties for type-specific labels
   - Import RULE_TERM constants
   - Run tests: `yarn test:unit components/shared/RuleList.spec.js`
   - All tests pass ✓

#### 3.2: RuleOverview Component

**Tests:** `app/javascript/__tests__/components/shared/RuleOverview.spec.js`

1. **Test conditional rendering:**
   ```javascript
   describe('RuleOverview', () => {
     const stigRule = {
       id: 1,
       rule_id: 'SRG-001',
       version: 'V-001',
       title: 'Test',
       rule_severity: 'high',
       vuln_id: 'V-123456',
       srg_id: 'SRG-001',
       ident: 'CCI-000366, 8:3.14, T1565'
     };

     const srgRule = {
       id: 2,
       rule_id: 'SRG-001',
       version: 'V1R1',
       title: 'Test',
       rule_severity: 'medium',
       ident: 'CCI-000366'
     };

     describe('STIG mode', () => {
       it('displays Vuln ID', () => {
         const wrapper = mount(RuleOverview, {
           propsData: { type: 'stig', selectedRule: stigRule }
         });
         expect(wrapper.text()).toContain('Vuln ID');
         expect(wrapper.text()).toContain('V-123456');
       });

       it('displays SRG ID', () => {
         const wrapper = mount(RuleOverview, {
           propsData: { type: 'stig', selectedRule: stigRule }
         });
         expect(wrapper.text()).toContain('SRG ID');
         expect(wrapper.text()).toContain('SRG-001');
       });

       it('displays STIG ID label for version', () => {
         const wrapper = mount(RuleOverview, {
           propsData: { type: 'stig', selectedRule: stigRule }
         });
         expect(wrapper.text()).toContain('STIG ID');
       });
     });

     describe('SRG mode', () => {
       it('does not display Vuln ID', () => {
         const wrapper = mount(RuleOverview, {
           propsData: { type: 'srg', selectedRule: srgRule }
         });
         expect(wrapper.text()).not.toContain('Vuln ID');
       });

       it('does not display SRG ID', () => {
         const wrapper = mount(RuleOverview, {
           propsData: { type: 'srg', selectedRule: srgRule }
         });
         expect(wrapper.text()).not.toContain('SRG ID');
       });

       it('displays Version label for version', () => {
         const wrapper = mount(RuleOverview, {
           propsData: { type: 'srg', selectedRule: srgRule }
         });
         expect(wrapper.text()).toContain('Version');
       });
     });

     describe('ident parsing', () => {
       it('displays parsed CCI', () => {
         const wrapper = mount(RuleOverview, {
           propsData: { type: 'stig', selectedRule: stigRule }
         });
         expect(wrapper.text()).toContain('CCI-000366');
       });

       it('displays parsed CIS Controls', () => {
         const wrapper = mount(RuleOverview, {
           propsData: { type: 'stig', selectedRule: stigRule }
         });
         expect(wrapper.text()).toContain('CIS Controls v8');
         expect(wrapper.text()).toContain('3.14');
       });

       it('displays parsed MITRE techniques', () => {
         const wrapper = mount(RuleOverview, {
           propsData: { type: 'stig', selectedRule: stigRule }
         });
         expect(wrapper.text()).toContain('ATT&CK Techniques');
         expect(wrapper.text()).toContain('T1565');
       });
     });
   });
   ```

2. **Implementation:**
   - Rename `app/javascript/components/stigs/StigRuleOverview.vue` → `app/javascript/components/shared/RuleOverview.vue`
   - Add `type` prop
   - Add conditional rendering for STIG-specific fields
   - Import parseIdents, formatCisControl utilities
   - Add CIS Controls and MITRE ATT&CK sections
   - Run tests: `yarn test:unit components/shared/RuleOverview.spec.js`
   - All tests pass ✓

#### 3.3: RuleDetails Component

**Tests:** `app/javascript/__tests__/components/shared/RuleDetails.spec.js`

1. **Test basic rendering:**
   ```javascript
   describe('RuleDetails', () => {
     const mockRule = {
       id: 1,
       title: 'Test Rule',
       fixtext: 'Fix instructions here',
       vendor_comments: 'Vendor note',
       disa_rule_descriptions_attributes: [
         { vuln_discussion: 'Vulnerability details' }
       ],
       checks_attributes: [
         { content: 'Check content' }
       ]
     };

     it('renders rule title', () => {
       const wrapper = mount(RuleDetails, {
         propsData: { type: 'stig', selectedRule: mockRule }
       });
       expect(wrapper.text()).toContain('Test Rule');
     });

     it('renders fix text', () => {
       const wrapper = mount(RuleDetails, {
         propsData: { type: 'stig', selectedRule: mockRule }
       });
       expect(wrapper.find('textarea[id^="rule-fixtext"]').element.value)
         .toBe('Fix instructions here');
     });

     it('renders vendor comments when present', () => {
       const wrapper = mount(RuleDetails, {
         propsData: { type: 'stig', selectedRule: mockRule }
       });
       expect(wrapper.text()).toContain('Vendor Comments');
     });
   });
   ```

2. **Implementation:**
   - Rename `app/javascript/components/stigs/StigRuleDetails.vue` → `app/javascript/components/shared/RuleDetails.vue`
   - Add `type` prop (for future expansion)
   - Update ID prefixes from `stig-rule-*` to `rule-*`
   - Run tests: `yarn test:unit components/shared/RuleDetails.spec.js`
   - All tests pass ✓

### Phase 4: Update BenchmarkViewer (TDD)

**Tests:** `app/javascript/__tests__/components/shared/BenchmarkViewer.spec.js`

1. **Test state management:**
   ```javascript
   describe('BenchmarkViewer', () => {
     const mockBenchmark = {
       id: 1,
       title: 'Test STIG',
       version: 'V1R1',
       rules: [
         { id: 1, rule_id: 'SRG-001', version: 'V-001', title: 'Rule 1', rule_severity: 'high' },
         { id: 2, rule_id: 'SRG-002', version: 'V-002', title: 'Rule 2', rule_severity: 'low' }
       ]
     };

     it('selects first rule on mount', () => {
       const wrapper = mount(BenchmarkViewer, {
         propsData: { type: 'stig', benchmark: mockBenchmark }
       });
       expect(wrapper.vm.selectedRule).toEqual(mockBenchmark.rules[0]);
     });

     it('sorts rules by rule_id', () => {
       const unsortedBenchmark = {
         ...mockBenchmark,
         rules: [
           { id: 2, rule_id: 'SRG-002', version: 'V-002', title: 'Rule 2' },
           { id: 1, rule_id: 'SRG-001', version: 'V-001', title: 'Rule 1' }
         ]
       };
       const wrapper = mount(BenchmarkViewer, {
         propsData: { type: 'stig', benchmark: unsortedBenchmark }
       });
       expect(wrapper.vm.sortedRules[0].rule_id).toBe('SRG-001');
       expect(wrapper.vm.sortedRules[1].rule_id).toBe('SRG-002');
     });

     it('updates selectedRule when rule-selected event emitted', () => {
       const wrapper = mount(BenchmarkViewer, {
         propsData: { type: 'stig', benchmark: mockBenchmark }
       });
       wrapper.vm.selectRule(mockBenchmark.rules[1]);
       expect(wrapper.vm.selectedRule).toEqual(mockBenchmark.rules[1]);
     });

     it('passes type prop to child components', () => {
       const wrapper = mount(BenchmarkViewer, {
         propsData: { type: 'stig', benchmark: mockBenchmark }
       });
       expect(wrapper.findComponent(RuleList).props('type')).toBe('stig');
       expect(wrapper.findComponent(RuleDetails).props('type')).toBe('stig');
       expect(wrapper.findComponent(RuleOverview).props('type')).toBe('stig');
     });
   });
   ```

2. **Implementation:**
   - Update `app/javascript/components/shared/BenchmarkViewer.vue`
   - Remove useBenchmarkViewer composable
   - Add simple state management (selectedRule ref, sortedRules computed)
   - Update component imports (RuleList, RuleDetails, RuleOverview from shared/)
   - Pass `type` prop to all child components
   - Run tests: `yarn test:unit components/shared/BenchmarkViewer.spec.js`
   - All tests pass ✓

### Phase 5: Update Page Wrappers (TDD)

#### 5.1: Stig.vue

**Tests:** `app/javascript/__tests__/components/stigs/Stig.spec.js`

1. **Test adapter integration:**
   ```javascript
   import { stigToBenchmark } from '@/adapters/benchmark';

   describe('Stig.vue', () => {
     const mockStig = {
       id: 1,
       stig_id: 'TEST_STIG',
       title: 'Test STIG',
       version: 'V1R1',
       benchmark_date: '2024-01-01',
       stig_rules: [
         { id: 1, rule_id: 'SRG-001', version: 'V-001', title: 'Rule 1' }
       ]
     };

     it('applies stigToBenchmark adapter', () => {
       const wrapper = mount(Stig, {
         propsData: { stig: mockStig }
       });
       const adapted = wrapper.vm.adaptedStig;
       expect(adapted.benchmark_id).toBe('TEST_STIG');
       expect(adapted.date).toBe('2024-01-01');
       expect(adapted.rules).toHaveLength(1);
     });

     it('passes adapted data to BenchmarkViewer', () => {
       const wrapper = mount(Stig, {
         propsData: { stig: mockStig }
       });
       const benchmarkViewer = wrapper.findComponent(BenchmarkViewer);
       expect(benchmarkViewer.props('benchmark').benchmark_id).toBe('TEST_STIG');
       expect(benchmarkViewer.props('type')).toBe('stig');
     });
   });
   ```

2. **Implementation:**
   - Update `app/javascript/components/stigs/Stig.vue`
   - Import stigToBenchmark adapter
   - Add computed property: `adaptedStig`
   - Pass `:benchmark="adaptedStig"` to BenchmarkViewer
   - Run tests: `yarn test:unit components/stigs/Stig.spec.js`
   - All tests pass ✓

#### 5.2: Srg.vue

**Tests:** `app/javascript/__tests__/components/srgs/Srg.spec.js`

1. **Test adapter integration:**
   ```javascript
   import { srgToBenchmark } from '@/adapters/benchmark';

   describe('Srg.vue', () => {
     const mockSrg = {
       id: 1,
       srg_id: 'TEST_SRG',
       title: 'Test SRG',
       version: 'V1R1',
       release_date: '2024-01-01',
       srg_rules: [
         { id: 1, rule_id: 'SRG-001', version: 'V1R1', title: 'Rule 1' }
       ]
     };

     it('applies srgToBenchmark adapter', () => {
       const wrapper = mount(Srg, {
         propsData: { srg: mockSrg }
       });
       const adapted = wrapper.vm.adaptedSrg;
       expect(adapted.benchmark_id).toBe('TEST_SRG');
       expect(adapted.date).toBe('2024-01-01');
       expect(adapted.rules).toHaveLength(1);
     });

     it('passes adapted data to BenchmarkViewer', () => {
       const wrapper = mount(Srg, {
         propsData: { srg: mockSrg }
       });
       const benchmarkViewer = wrapper.findComponent(BenchmarkViewer);
       expect(benchmarkViewer.props('benchmark').benchmark_id).toBe('TEST_SRG');
       expect(benchmarkViewer.props('type')).toBe('srg');
     });
   });
   ```

2. **Implementation:**
   - Create `app/javascript/components/srgs/Srg.vue`
   - Import srgToBenchmark adapter
   - Add computed property: `adaptedSrg`
   - Render BenchmarkViewer with `:benchmark="adaptedSrg"` and `type="srg"`
   - Run tests: `yarn test:unit components/srgs/Srg.spec.js`
   - All tests pass ✓

### Phase 6: Integration Testing

**Manual Testing Checklist:**

1. **STIG Viewing (`/stigs/:id`):**
   - [ ] Page loads without errors
   - [ ] Breadcrumb shows "STIGs > {Title} {Version}"
   - [ ] Left panel shows rule list with "SRG ID" / "STIG ID" toggle
   - [ ] Middle panel shows rule details (vuln discussion, check, fix)
   - [ ] Right panel shows rule overview with:
     - [ ] Vuln ID (STIG-specific)
     - [ ] Rule ID
     - [ ] STIG ID
     - [ ] SRG ID (STIG-specific)
     - [ ] Severity badge
     - [ ] CCI identifiers
     - [ ] CIS Controls (if present)
     - [ ] MITRE ATT&CK (if present)
   - [ ] Clicking rule in list updates details/overview
   - [ ] Search filters rules
   - [ ] Severity filters work (High, Medium, Low, All)
   - [ ] Download button opens export modal

2. **SRG Viewing (`/srgs/:id`):**
   - [ ] Page loads without errors
   - [ ] Breadcrumb shows "SRGs > {Title} {Version}"
   - [ ] Left panel shows rule list with "Rule ID" / "Version" toggle
   - [ ] Middle panel shows rule details
   - [ ] Right panel shows rule overview with:
     - [ ] Rule ID
     - [ ] Version (not labeled "STIG ID")
     - [ ] Severity badge
     - [ ] CCI identifiers
     - [ ] NO Vuln ID field
     - [ ] NO SRG ID field
   - [ ] All interactions work same as STIG

3. **Terminology:**
   - [ ] All uses of "Rule" come from RULE_TERM constants
   - [ ] No hardcoded "Rules" strings in components

4. **Accessibility:**
   - [ ] Tooltips work on info icons
   - [ ] Links to CIS Controls and MITRE ATT&CK open in new tab
   - [ ] Keyboard navigation works
   - [ ] Screen reader friendly (ARIA labels correct)

### Phase 7: Cleanup and Documentation

1. **Delete old files:**
   - Remove `app/javascript/components/stigs/StigRuleList.vue` (moved to shared/RuleList.vue)
   - Remove `app/javascript/components/stigs/StigRuleDetails.vue` (moved to shared/RuleDetails.vue)
   - Remove `app/javascript/components/stigs/StigRuleOverview.vue` (moved to shared/RuleOverview.vue)

2. **Update imports:**
   - Search for any remaining imports of old component paths
   - Update to new shared/ paths

3. **Documentation:**
   - Update CLAUDE.md with BenchmarkViewer architecture
   - Add JSDoc comments to adapter functions
   - Update component README if exists

4. **Final test run:**
   ```bash
   # Unit tests
   yarn test:unit

   # Lint
   yarn lint

   # Full suite
   bundle exec rspec
   ```

---

## Test-Driven Development Flow

For each phase, follow this exact pattern:

1. **RED Phase** - Write failing tests first
   - Write test file before implementation
   - Run tests: `yarn test:unit <file>`
   - Tests FAIL (expected) ❌

2. **GREEN Phase** - Implement minimum code to pass
   - Write implementation
   - Run tests: `yarn test:unit <file>`
   - Tests PASS ✓

3. **REFACTOR Phase** - Clean up code
   - Improve readability
   - Extract duplications
   - Run tests: Still PASS ✓

4. **COMMIT** - Save progress
   - Commit test file + implementation together
   - Message: `test: Add [component] tests` + `feat: Implement [component]`

**DO NOT:**
- Write implementation before tests
- Skip test files
- Modify tests just to make them pass
- Move to next phase with failing tests

---

## Summary

This design provides a complete, test-driven path to backport v2.3.0's BenchmarkViewer pattern to v2.2.x:

**Key Differences from v2.3.0:**
- JavaScript adapters instead of TypeScript interfaces
- Vue 2.7 patterns (no `<script setup>`)
- RULE_TERM constants for terminology
- Simplified state management (no complex composable)

**Benefits:**
- Reusable components for STIG and SRG viewing
- Single source of truth for adapter logic
- Type-safe (via prop validation, not TypeScript)
- Test-driven implementation (TDD)
- Maintainable and extensible

**Implementation Order:**
1. Adapters (stigToBenchmark, srgToBenchmark)
2. Utilities (parseIdents, formatCisControl)
3. Shared Components (RuleList, RuleDetails, RuleOverview)
4. BenchmarkViewer (state management)
5. Page Wrappers (Stig.vue, Srg.vue)
6. Integration Testing
7. Cleanup

Follow TDD strictly: **Tests → Implementation → Refactor → Commit**
