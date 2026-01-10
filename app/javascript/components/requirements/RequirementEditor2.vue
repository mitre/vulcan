<script setup lang="ts">
import type { IComponent, IProject } from '@/types'
import { BBadge, BButton, BCard, BFormGroup, BFormSelect, BFormTextarea, BNav, BNavItem, BOffcanvas, BProgress } from 'bootstrap-vue-next'
import { computed, ref } from 'vue'
import { useRules } from '@/composables'
import { RULE_STATUSES } from '@/config'

// Props
interface Props {
  componentId: number
  component: IComponent
  project: IProject
  canGoBack?: boolean
  canGoForward?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  canGoBack: false,
  canGoForward: false,
})

// Emits
const emit = defineEmits<{
  navigatePrevious: []
  navigateNext: []
}>()

// Get current rule from composable (has full data)
const { currentRule, rules } = useRules()

// Field locking state (based on rule.locked and individual fields)
const locks = computed(() => ({
  title: currentRule?.locked || false,
  vulnDiscussion: currentRule?.locked || false,
  check: currentRule?.locked || false,
  fix: currentRule?.locked || false,
}))

// Reference panel
const activeReferenceTab = ref('rhel8')
const referencePanelOpen = ref(true)

const referenceData = ref({
  rhel8: {
    vulnDiscussion: 'Terminating idle sessions limits exposure window for attackers who could exploit unattended terminals...',
    check: 'Verify SSH ClientAliveInterval is set to 600 or less:\n$ grep ClientAliveInterval /etc/ssh/sshd_config',
    fix: 'Configure SSH daemon:\nClientAliveInterval 600\nClientAliveCountMax 0',
  },
  win22: {
    vulnDiscussion: 'Idle session termination prevents unauthorized access to unattended workstations...',
    check: 'Verify idle timeout via Group Policy or local security policy...',
    fix: 'Set screen saver timeout to 15 minutes or less via GPO...',
  },
})

// Progress (calculated from rules list)
const progress = computed(() => {
  if (!currentRule) return { current: 0, total: 0, percentage: 0 }
  const total = rules.value.length
  const current = rules.value.findIndex(r => r.id === currentRule.id) + 1
  return {
    current,
    total,
    percentage: total > 0 ? (current / total) * 100 : 0,
  }
})

// Automation tabs
const activeAutomationTab = ref('inspec')

// Functions
function toggleLock(field: string) {
  locks.value[field] = !locks.value[field]
}

function expandField(_field: string) {
  // TODO: Open modal for full-screen editing
  // _field parameter will be used when implementing the modal
}

async function copyToClipboard(text: string) {
  await navigator.clipboard.writeText(text)
  // TODO: Show toast
}

function navigatePrevious() {
  emit('navigatePrevious')
}

function navigateNext() {
  emit('navigateNext')
}

function lockRemaining() {
  Object.keys(locks.value).forEach((key) => {
    if (!locks.value[key]) locks.value[key] = true
  })
}

function requestReview() {
  // TODO: Implement review request workflow
}
</script>

<template>
  <div v-if="currentRule" class="requirement-editor-2">
    <!-- Header Bar -->
    <div class="editor-header">
      <div class="header-left">
        <h5 class="component-title mb-0">
          {{ props.component.title || 'Component' }}
        </h5>
        <div class="progress-section">
          <BProgress :value="progress.percentage" :max="100" class="progress-bar-custom" />
          <span class="progress-text">{{ progress.current }}/{{ progress.total }}</span>
        </div>
        <BFormSelect v-if="currentRule" v-model="currentRule.status" size="sm" class="filter-select">
          <option v-for="status in RULE_STATUSES" :key="status" :value="status">
            {{ status }}
          </option>
        </BFormSelect>
      </div>
      <div class="header-right">
        <BBadge v-if="currentRule" variant="primary" class="srg-badge">
          {{ currentRule.rule_id }}
        </BBadge>
        <div class="nav-buttons">
          <BButton size="sm" variant="outline-secondary" :disabled="!props.canGoBack" @click="navigatePrevious">
            ←
          </BButton>
          <BButton size="sm" variant="outline-secondary" :disabled="!props.canGoForward" @click="navigateNext">
            →
          </BButton>
        </div>
        <BButton
          size="sm"
          variant="outline-info"
          @click="referencePanelOpen = !referencePanelOpen"
        >
          📖 References
        </BButton>
        <BBadge :variant="locks.title ? 'danger' : 'success'">
          {{ locks.title ? '🔒' : '🔓' }}
        </BBadge>
      </div>
    </div>

    <!-- Main Content Area -->
    <div class="row g-3 editor-content">
      <!-- Main Column: Your Content (Full Width) -->
      <div class="col-12">
        <div class="content-column">
          <div class="column-header">
            <h6 class="mb-0">
              YOUR CONTENT
            </h6>
          </div>

          <!-- Status and Severity -->
          <div class="status-row mb-3">
            <BFormGroup label="Status:" label-cols="3" class="mb-0">
              <BFormSelect v-if="currentRule" v-model="currentRule.status" size="sm">
                <option v-for="status in RULE_STATUSES" :key="status" :value="status">
                  {{ status }}
                </option>
              </BFormSelect>
            </BFormGroup>
            <BBadge v-if="currentRule" variant="warning" class="ms-2 severity-badge">
              {{ currentRule.rule_severity }}
            </BBadge>
          </div>

          <!-- Title Field -->
          <BCard class="field-card mb-3" :class="{ 'field-locked': locks.title }">
            <template #header>
              <div class="field-header">
                <span class="field-label">Title</span>
                <div class="field-actions">
                  <BButton
                    size="sm"
                    :variant="locks.title ? 'danger' : 'outline-secondary'"
                    @click="toggleLock('title')"
                  >
                    {{ locks.title ? '🔒 Locked' : '🔓' }}
                  </BButton>
                </div>
              </div>
            </template>
            <BFormTextarea
              v-model="currentRule.title"
              :disabled="locks.title"
              rows="2"
              class="field-textarea"
              readonly
            />
          </BCard>

          <!-- Vuln Discussion Field -->
          <BCard class="field-card mb-3" :class="{ 'field-locked': locks.vulnDiscussion }">
            <template #header>
              <div class="field-header">
                <span class="field-label">Vulnerability Discussion</span>
                <div class="field-actions">
                  <BButton
                    size="sm"
                    variant="link"
                    class="expand-btn"
                    @click="expandField('vulnDiscussion')"
                  >
                    ⤢
                  </BButton>
                  <BButton
                    size="sm"
                    :variant="locks.vulnDiscussion ? 'danger' : 'outline-secondary'"
                    @click="toggleLock('vulnDiscussion')"
                  >
                    {{ locks.vulnDiscussion ? '🔒' : '🔓' }}
                  </BButton>
                </div>
              </div>
            </template>
            <BFormTextarea
              :model-value="currentRule.disa_rule_descriptions?.[0]?.vuln_discussion || ''"
              :disabled="locks.vulnDiscussion"
              rows="4"
              class="field-textarea"
            />
          </BCard>

          <!-- Check Field -->
          <BCard class="field-card mb-3" :class="{ 'field-locked': locks.check }">
            <template #header>
              <div class="field-header">
                <span class="field-label">Check</span>
                <div class="field-actions">
                  <BButton
                    size="sm"
                    variant="link"
                    class="expand-btn"
                    @click="expandField('check')"
                  >
                    ⤢
                  </BButton>
                  <BButton
                    size="sm"
                    :variant="locks.check ? 'danger' : 'outline-secondary'"
                    @click="toggleLock('check')"
                  >
                    {{ locks.check ? '🔒' : '🔓' }}
                  </BButton>
                  <BButton
                    v-if="!locks.check"
                    size="sm"
                    variant="outline-primary"
                    @click="toggleLock('check')"
                  >
                    Lock🔒
                  </BButton>
                </div>
              </div>
            </template>
            <BFormTextarea
              :model-value="currentRule.checks?.[0]?.content || ''"
              :disabled="locks.check"
              rows="5"
              class="field-textarea code-field"
            />
          </BCard>

          <!-- Fix Field -->
          <BCard class="field-card mb-3" :class="{ 'field-locked': locks.fix }">
            <template #header>
              <div class="field-header">
                <span class="field-label">Fix</span>
                <div class="field-actions">
                  <BButton
                    size="sm"
                    variant="link"
                    class="expand-btn"
                    @click="expandField('fix')"
                  >
                    ⤢
                  </BButton>
                  <BButton
                    size="sm"
                    :variant="locks.fix ? 'danger' : 'outline-secondary'"
                    @click="toggleLock('fix')"
                  >
                    {{ locks.fix ? '🔒' : '🔓' }}
                  </BButton>
                  <BButton
                    v-if="!locks.fix"
                    size="sm"
                    variant="outline-primary"
                    @click="toggleLock('fix')"
                  >
                    Lock🔒
                  </BButton>
                </div>
              </div>
            </template>
            <BFormTextarea
              :model-value="currentRule.fixtext || ''"
              :disabled="locks.fix"
              rows="4"
              class="field-textarea code-field"
            />
          </BCard>

          <!-- Automation Section -->
          <BCard class="field-card automation-card">
            <template #header>
              <div class="field-header">
                <span class="field-label">Automation</span>
                <BButton size="sm" variant="outline-success">
                  + Add
                </BButton>
              </div>
            </template>

            <BNav tabs class="automation-tabs mb-3">
              <BNavItem
                :active="activeAutomationTab === 'inspec'"
                @click="activeAutomationTab = 'inspec'"
              >
                InSpec ●
              </BNavItem>
              <BNavItem
                :active="activeAutomationTab === 'ansible'"
                @click="activeAutomationTab = 'ansible'"
              >
                Ansible
              </BNavItem>
              <BNavItem
                :active="activeAutomationTab === 'chef'"
                @click="activeAutomationTab = 'chef'"
              >
                Chef
              </BNavItem>
              <BNavItem
                :active="activeAutomationTab === 'shell'"
                @click="activeAutomationTab = 'shell'"
              >
                Shell
              </BNavItem>
            </BNav>

            <div v-if="activeAutomationTab === 'inspec' && currentRule" class="automation-content">
              <pre class="code-block"><code>{{ currentRule.inspec_control_file || 'No InSpec code yet' }}</code></pre>
              <div class="code-actions">
                <BButton size="sm" variant="link" @click="expandField('automation')">
                  ⤢
                </BButton>
                <BButton size="sm" variant="outline-primary" @click="copyToClipboard(currentRule.inspec_control_file || '')">
                  Copy
                </BButton>
              </div>
            </div>
          </BCard>

          <!-- Footer Actions -->
          <div class="editor-footer">
            <div class="footer-left">
              <BButton variant="link" size="sm">
                💬 Reviews 2
              </BButton>
              <BButton variant="link" size="sm">
                📜 History 5
              </BButton>
            </div>
            <div class="footer-right">
              <BButton variant="outline-warning" @click="lockRemaining">
                Lock Remaining
              </BButton>
              <BButton variant="primary" @click="requestReview">
                Request Review
              </BButton>
            </div>
          </div>
        </div>
      </div>

      <!-- Reference Panel Slideover -->
      <BOffcanvas
        v-model="referencePanelOpen"
        placement="end"
        title="REFERENCE STIGS"
        class="reference-slideover"
        backdrop
        body-scrolling
      >
        <template #header>
          <div class="slideover-header">
            <h5 class="mb-0">
              REFERENCE
            </h5>
            <BNav pills class="reference-tabs">
              <BNavItem
                :active="activeReferenceTab === 'rhel8'"
                size="sm"
                @click="activeReferenceTab = 'rhel8'"
              >
                RHEL 8
              </BNavItem>
              <BNavItem
                :active="activeReferenceTab === 'win22'"
                size="sm"
                @click="activeReferenceTab = 'win22'"
              >
                Win 22
              </BNavItem>
            </BNav>
          </div>
        </template>

        <div class="reference-content">
          <!-- Vuln Discussion Reference -->
          <BCard class="reference-card mb-3">
            <template #header>
              <div class="reference-header">
                <span class="ref-field-label">Vuln Discussion</span>
                <BButton
                  size="sm"
                  variant="link"
                  class="copy-ref-btn"
                  @click="copyToClipboard(referenceData[activeReferenceTab].vulnDiscussion)"
                >
                  📋 Copy
                </BButton>
              </div>
            </template>
            <p class="ref-text">
              {{ referenceData[activeReferenceTab].vulnDiscussion }}
            </p>
          </BCard>

          <!-- Check Reference -->
          <BCard class="reference-card mb-3">
            <template #header>
              <div class="reference-header">
                <span class="ref-field-label">Check</span>
                <BButton
                  size="sm"
                  variant="link"
                  class="copy-ref-btn"
                  @click="copyToClipboard(referenceData[activeReferenceTab].check)"
                >
                  📋 Copy
                </BButton>
              </div>
            </template>
            <pre class="ref-code">{{ referenceData[activeReferenceTab].check }}</pre>
          </BCard>

          <!-- Fix Reference -->
          <BCard class="reference-card mb-3">
            <template #header>
              <div class="reference-header">
                <span class="ref-field-label">Fix</span>
                <BButton
                  size="sm"
                  variant="link"
                  class="copy-ref-btn"
                  @click="copyToClipboard(referenceData[activeReferenceTab].fix)"
                >
                  📋 Copy
                </BButton>
              </div>
            </template>
            <pre class="ref-code">{{ referenceData[activeReferenceTab].fix }}</pre>
          </BCard>

          <BButton variant="link" size="sm" class="more-refs-btn w-100">
            More references →
          </BButton>
        </div>
      </BOffcanvas>
    </div>
  </div>
</template>

<style scoped>
/* STIG-Inspired Aesthetic: Technical Documentation meets Modern UI */

.requirement-editor-2 {
  background: var(--bs-body-bg);
  min-height: 100vh;
  padding: 1rem;
}

/* Header Bar */
.editor-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.5rem;
  background: var(--bs-secondary-bg);
  border-bottom: 2px solid var(--bs-border-color);
  margin-bottom: 1.5rem;
  border-radius: var(--bs-border-radius) var(--bs-border-radius) 0 0;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 1.5rem;
}

.component-title {
  font-weight: 700;
  letter-spacing: 0.05em;
  color: var(--bs-emphasis-color);
  font-family: var(--bs-font-monospace);
}

.progress-section {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.progress-bar-custom {
  width: 120px;
  height: 8px;
}

.progress-text {
  font-size: 0.85rem;
  font-family: var(--bs-font-monospace);
  color: var(--bs-secondary-color);
}

.filter-select {
  width: auto;
  min-width: 150px;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.srg-badge {
  font-family: var(--bs-font-monospace);
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
}

.nav-buttons {
  display: flex;
  gap: 0.25rem;
}

/* Column Headers */
.column-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1rem;
  background: var(--bs-tertiary-bg);
  border-bottom: 1px solid var(--bs-border-color);
  margin-bottom: 1rem;
  font-family: var(--bs-font-monospace);
  letter-spacing: 0.05em;
}

.column-header h6 {
  margin: 0;
  font-weight: 600;
  color: var(--bs-secondary-color);
  font-size: 0.75rem;
}

.reference-tabs {
  gap: 0.5rem;
}

.reference-tabs .nav-item {
  font-size: 0.8rem;
  font-family: var(--bs-font-monospace);
}

/* Content Columns */
.content-column,
.reference-column {
  height: calc(100vh - 180px);
  overflow-y: auto;
  padding-right: 0.5rem;
}

/* Status Row */
.status-row {
  display: flex;
  align-items: center;
  padding: 0.75rem 1rem;
  background: var(--bs-secondary-bg);
  border-radius: var(--bs-border-radius);
}

.severity-badge {
  font-family: var(--bs-font-monospace);
  padding: 0.35rem 0.75rem;
}

/* Field Cards */
.field-card {
  border: 1px solid var(--bs-border-color);
  transition: all 0.2s ease;
}

.field-card:hover {
  border-color: var(--bs-primary);
  box-shadow: 0 0 0 0.2rem rgba(var(--bs-primary-rgb), 0.1);
}

.field-card.field-locked {
  background: var(--bs-secondary-bg);
  opacity: 0.85;
}

.field-card.field-locked .card-header {
  background: var(--bs-danger-bg-subtle);
  border-bottom-color: var(--bs-danger-border-subtle);
}

.field-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-family: var(--bs-font-monospace);
}

.field-label {
  font-weight: 600;
  font-size: 0.875rem;
  color: var(--bs-emphasis-color);
  letter-spacing: 0.03em;
}

.field-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.expand-btn {
  font-size: 1.2rem;
  line-height: 1;
  padding: 0.25rem 0.5rem;
  color: var(--bs-secondary-color);
}

.expand-btn:hover {
  color: var(--bs-primary);
}

.field-textarea {
  border: none;
  resize: vertical;
  font-size: 0.95rem;
  font-family: var(--bs-body-font-family);
  background: transparent;
}

.field-textarea:focus {
  box-shadow: none;
  background: var(--bs-body-bg);
}

.code-field {
  font-family: var(--bs-font-monospace);
  font-size: 0.875rem;
}

/* Automation Card */
.automation-card .card-header {
  background: var(--bs-success-bg-subtle);
  border-bottom-color: var(--bs-success-border-subtle);
}

.automation-tabs {
  border-bottom: 1px solid var(--bs-border-color);
}

.automation-tabs .nav-item {
  font-family: var(--bs-font-monospace);
  font-size: 0.875rem;
}

.automation-content {
  position: relative;
}

.code-block {
  background: var(--bs-secondary-bg);
  padding: 1rem;
  border-radius: var(--bs-border-radius);
  margin: 0;
  font-size: 0.875rem;
  line-height: 1.6;
  overflow-x: auto;
}

.code-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
  margin-top: 0.75rem;
}

/* Reference Column */
.reference-content {
  padding: 0 1rem;
}

.reference-card {
  border: 1px solid var(--bs-border-color);
  background: var(--bs-tertiary-bg);
}

.reference-card .card-header {
  background: var(--bs-info-bg-subtle);
  border-bottom: 1px solid var(--bs-info-border-subtle);
  padding: 0.5rem 0.75rem;
}

.reference-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.ref-field-label {
  font-weight: 600;
  font-size: 0.8rem;
  font-family: var(--bs-font-monospace);
  color: var(--bs-emphasis-color);
}

.copy-ref-btn {
  font-size: 0.8rem;
  padding: 0.25rem 0.5rem;
  text-decoration: none;
}

.ref-text {
  font-size: 0.875rem;
  line-height: 1.6;
  margin: 0;
  color: var(--bs-body-color);
}

.ref-code {
  font-size: 0.8rem;
  line-height: 1.5;
  margin: 0;
  font-family: var(--bs-font-monospace);
  background: var(--bs-secondary-bg);
  padding: 0.75rem;
  border-radius: var(--bs-border-radius-sm);
  white-space: pre-wrap;
  color: var(--bs-body-color);
}

.more-refs-btn {
  width: 100%;
  text-align: center;
  font-size: 0.85rem;
  color: var(--bs-secondary-color);
}

/* Editor Footer */
.editor-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.5rem 1rem 1rem;
  border-top: 1px solid var(--bs-border-color);
  margin-top: 1.5rem;
}

.footer-left {
  display: flex;
  gap: 1rem;
}

.footer-right {
  display: flex;
  gap: 0.75rem;
}

/* Scrollbar Styling */
.content-column::-webkit-scrollbar,
.reference-column::-webkit-scrollbar {
  width: 8px;
}

.content-column::-webkit-scrollbar-track,
.reference-column::-webkit-scrollbar-track {
  background: var(--bs-tertiary-bg);
}

.content-column::-webkit-scrollbar-thumb,
.reference-column::-webkit-scrollbar-thumb {
  background: var(--bs-border-color);
  border-radius: 4px;
}

.content-column::-webkit-scrollbar-thumb:hover,
.reference-column::-webkit-scrollbar-thumb:hover {
  background: var(--bs-secondary-color);
}

/* Responsive */
@media (max-width: 991px) {
  .editor-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 1rem;
  }

  .header-left,
  .header-right {
    width: 100%;
    justify-content: space-between;
  }

  .content-column,
  .reference-column {
    height: auto;
  }
}
</style>
