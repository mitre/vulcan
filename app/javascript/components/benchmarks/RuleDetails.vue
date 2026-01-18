<script setup lang="ts">
/**
 * RuleDetails.vue
 *
 * Rule detail view showing vulnerability discussion, check content, and fix text.
 * Middle panel component.
 */
import type { BenchmarkType, IBenchmarkRule } from '@/types'
import { BFormTextarea } from 'bootstrap-vue-next'
import { computed } from 'vue'

const props = defineProps<{
  type: BenchmarkType
  rule: IBenchmarkRule
}>()

// Extract vulnerability discussion from disa_rule_descriptions
const vulnDiscussion = computed(() => {
  const desc = props.rule.disa_rule_descriptions_attributes?.[0]
  return desc?.vuln_discussion || ''
})

// Extract check content
const checkContent = computed(() => {
  const check = props.rule.checks_attributes?.[0]
  return check?.content || ''
})
</script>

<template>
  <div class="card h-100">
    <div class="card-header">
      <h5 class="card-title mb-0">
        {{ rule.title }}
      </h5>
    </div>
    <div class="card-body">
      <!-- Vulnerability Discussion -->
      <div class="mb-3">
        <label class="form-label">
          <strong>Vulnerability Discussion</strong>
          <i
            class="bi bi-info-circle ms-1"
            data-bs-toggle="tooltip"
            title="Describes the vulnerability or security concern this rule addresses"
          />
        </label>
        <BFormTextarea
          :model-value="vulnDiscussion"
          disabled
          rows="3"
          max-rows="10"
        />
      </div>

      <!-- Check Content -->
      <div class="mb-3">
        <label class="form-label">
          <strong>Check</strong>
          <i
            class="bi bi-info-circle ms-1"
            data-bs-toggle="tooltip"
            title="Instructions for verifying if the system is compliant with this requirement"
          />
        </label>
        <BFormTextarea
          :model-value="checkContent"
          disabled
          rows="3"
          max-rows="10"
        />
      </div>

      <!-- Fix Text -->
      <div class="mb-3">
        <label class="form-label">
          <strong>Fix</strong>
          <i
            class="bi bi-info-circle ms-1"
            data-bs-toggle="tooltip"
            title="Describes how to correctly configure the requirement to remediate the system vulnerability"
          />
        </label>
        <BFormTextarea
          :model-value="rule.fixtext || ''"
          disabled
          rows="3"
          max-rows="10"
        />
      </div>

      <!-- Vendor Comments (if present) -->
      <div v-if="rule.vendor_comments" class="mb-3">
        <label class="form-label">
          <strong>Vendor Comments</strong>
          <i
            class="bi bi-info-circle ms-1"
            data-bs-toggle="tooltip"
            title="Provides context to a reviewing authority; not a published field"
          />
        </label>
        <BFormTextarea
          :model-value="rule.vendor_comments"
          disabled
          rows="2"
          max-rows="10"
        />
      </div>
    </div>
  </div>
</template>
