<script setup lang="ts">
/**
 * RuleOverview.vue
 *
 * Rule metadata overview sidebar.
 * Right panel component showing IDs, severity, CCIs, CIS Controls, MITRE ATT&CK, etc.
 */
import type { BenchmarkType, IBenchmarkRule } from '@/types'
import { computed } from 'vue'
import { formatCisControl, parseIdents } from '@/utils'

const props = defineProps<{
  type: BenchmarkType
  rule: IBenchmarkRule
}>()

// Parse idents into categories
const parsedIdents = computed(() => parseIdents(props.rule.ident))

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

        <!-- CCIs (DISA Control Correlation Identifiers) -->
        <li v-if="parsedIdents.ccis.length > 0" class="list-group-item">
          <strong>CCI</strong>: {{ parsedIdents.ccis.join(', ') }}
        </li>

        <!-- NIST Control Family / IA Control -->
        <li v-if="rule.nist_control_family" class="list-group-item">
          <strong>IA Control</strong>: {{ rule.nist_control_family }}
        </li>

        <!-- CIS Controls v8 -->
        <li v-if="parsedIdents.cisV8.length > 0" class="list-group-item">
          <strong>CIS Controls v8</strong>:
          <span
            v-for="(control, idx) in parsedIdents.cisV8"
            :key="control"
          >
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
          <span
            v-for="(control, idx) in parsedIdents.cisV7"
            :key="control"
          >
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
          <span
            v-for="(tech, idx) in parsedIdents.mitreTechniques"
            :key="tech"
          >
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
          <span
            v-for="(tactic, idx) in parsedIdents.mitreTactics"
            :key="tactic"
          >
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
          <span
            v-for="(mit, idx) in parsedIdents.mitreMitigations"
            :key="mit"
          >
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
        <li v-if="rule.status" class="list-group-item">
          <strong>Status</strong>: {{ rule.status }}
        </li>
      </ul>
    </div>
  </div>
</template>
