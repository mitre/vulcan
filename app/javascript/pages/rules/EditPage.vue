<script setup lang="ts">
/**
 * Rule Edit Page
 *
 * Standalone rule editor for direct rule access.
 * Uses async setup with Suspense for loading state.
 *
 * TODO: Implement rule editing with useRules composable
 */
import { useRoute } from 'vue-router'
import PageContainer from '@/components/shared/PageContainer.vue'

const route = useRoute()
const ruleId = Number(route.params.id)

// TODO: Implement with async setup pattern:
// const { fetchRule } = useRules()
// const rule = await fetchRule(ruleId)
// if (!rule) throw new Error('Rule not found')
</script>

<template>
  <PageContainer>
    <h1>Edit Rule</h1>
    <p class="text-muted">
      Rule ID: {{ ruleId }} - implementation pending
    </p>
    <!-- TODO: Add RuleEditor component -->
  </PageContainer>
</template>
