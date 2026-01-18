<script setup lang="ts">
/**
 * Editor2 Demo Page
 *
 * Demo page for RequirementEditor2 component using real component/rule data.
 * Route: /components/:componentId/editor2
 */

import { BBadge, BButton } from 'bootstrap-vue-next'
import { computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getComponent } from '@/apis/components.api'
import { getProject } from '@/apis/projects.api'
import RequirementEditor2 from '@/components/requirements/RequirementEditor2.vue'
import PageContainer from '@/components/shared/PageContainer.vue'
import { useRules } from '@/composables'

const route = useRoute()
const router = useRouter()
const { fetchRules, rules, selectRule, currentRule, currentRuleId } = useRules()

// Top-level await for component and project data
const componentId = Number(route.params.componentId)
const componentResponse = await getComponent(componentId)
const component = componentResponse.data

if (!component) {
  throw new Error('Component not found')
}

const projectResponse = await getProject(component.project_id)
const project = projectResponse.data

if (!project) {
  throw new Error('Project not found')
}

// Fetch all rules
await fetchRules(componentId)

// Select first rule or from query param
onMounted(() => {
  const ruleId = route.query.rule ? Number(route.query.rule) : rules.value[0]?.id
  if (ruleId) {
    selectRule(ruleId)
  }
})

// Navigation
const currentIndex = computed(() => {
  if (!currentRuleId.value) return -1
  return rules.value.findIndex(r => r.id === currentRuleId.value)
})

const canGoBack = computed(() => currentIndex.value > 0)
const canGoForward = computed(() => currentIndex.value < rules.value.length - 1)

function navigatePrevious() {
  if (canGoBack.value) {
    const prevRule = rules.value[currentIndex.value - 1]
    selectRule(prevRule.id)
    router.push({ query: { rule: String(prevRule.id) } })
  }
}

function navigateNext() {
  if (canGoForward.value) {
    const nextRule = rules.value[currentIndex.value + 1]
    selectRule(nextRule.id)
    router.push({ query: { rule: String(nextRule.id) } })
  }
}

function backToControls() {
  router.push(`/components/${componentId}/controls`)
}
</script>

<template>
  <PageContainer>
    <div class="editor2-demo-page">
      <!-- Header with back button -->
      <div class="demo-header mb-3">
        <BButton variant="outline-secondary" size="sm" @click="backToControls">
          ← Back to Controls
        </BButton>
        <BBadge variant="info">
          Editor2 Demo - Bootstrap 5 + Slideover Pattern
        </BBadge>
        <div class="rule-nav">
          <span class="text-muted small">
            Rule {{ currentIndex + 1 }} of {{ rules.length }}
          </span>
        </div>
      </div>

      <!-- Editor Component -->
      <RequirementEditor2
        v-if="currentRule"
        :component-id="componentId"
        :component="component"
        :project="project"
        :can-go-back="canGoBack"
        :can-go-forward="canGoForward"
        @navigate-previous="navigatePrevious"
        @navigate-next="navigateNext"
      />
      <div v-else class="text-center text-muted py-5">
        <p>No rule selected</p>
      </div>
    </div>
  </PageContainer>
</template>

<style scoped>
.demo-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  background: var(--bs-secondary-bg);
  border-radius: var(--bs-border-radius);
}

.rule-nav {
  margin-left: auto;
}
</style>
