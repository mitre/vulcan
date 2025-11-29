<script setup lang="ts">
/**
 * RuleOverview.vue
 *
 * Rule metadata overview sidebar.
 * Right panel component showing IDs, severity, CCIs, etc.
 */
import type { BenchmarkType, IBenchmarkRule } from '@/types'
import { computed } from 'vue'

const props = defineProps<{
  type: BenchmarkType
  rule: IBenchmarkRule
}>()

// Severity badge class
const severityClass = computed(() => {
  switch (props.rule.rule_severity) {
    case 'high':
      return 'bg-danger'
    case 'medium':
      return 'bg-warning text-dark'
    case 'low':
      return 'bg-success'
    default:
      return 'bg-secondary'
  }
})

// Type-specific ID labels
const idLabel = computed(() => (props.type === 'stig' ? 'STIG ID' : 'Version'))
const primaryIdLabel = computed(() => (props.type === 'stig' ? 'SRG ID' : 'Rule ID'))
</script>

<template>
  <div class="card h-100">
    <div class="card-header">
      <h5 class="card-title mb-0">
        Requirement Overview
      </h5>
    </div>
    <div class="card-body p-0">
      <ul class="list-group list-group-flush">
        <!-- STIG-specific: Vuln ID -->
        <li v-if="type === 'stig' && rule.vuln_id" class="list-group-item">
          <strong>Vuln ID</strong>: {{ rule.vuln_id }}
        </li>

        <!-- Rule ID -->
        <li class="list-group-item">
          <strong>Rule ID</strong>: {{ rule.rule_id }}
        </li>

        <!-- Version / STIG ID -->
        <li class="list-group-item">
          <strong>{{ idLabel }}</strong>: {{ rule.version }}
        </li>

        <!-- STIG-specific: SRG ID -->
        <li v-if="type === 'stig' && rule.srg_id" class="list-group-item">
          <strong>SRG ID</strong>: {{ rule.srg_id }}
        </li>

        <!-- Severity -->
        <li class="list-group-item">
          <strong>Severity</strong>:
          <span class="badge" :class="[severityClass]">
            {{ rule.rule_severity }}
          </span>
        </li>

        <!-- Legacy IDs -->
        <li v-if="rule.legacy_ids" class="list-group-item">
          <strong>Legacy IDs</strong>: {{ rule.legacy_ids }}
        </li>

        <!-- CCI -->
        <li v-if="rule.ident" class="list-group-item">
          <strong>CCI</strong>: {{ rule.ident }}
        </li>

        <!-- NIST Control Family / IA Control -->
        <li v-if="rule.nist_control_family" class="list-group-item">
          <strong>IA Control</strong>: {{ rule.nist_control_family }}
        </li>

        <!-- Status (if present) -->
        <li v-if="rule.status" class="list-group-item">
          <strong>Status</strong>: {{ rule.status }}
        </li>
      </ul>
    </div>
  </div>
</template>
