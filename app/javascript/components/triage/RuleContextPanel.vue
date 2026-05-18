<template>
  <div class="rule-context-panel">
    <template v-if="ruleContent">
      <h6 class="mb-1 font-weight-bold">{{ ruleContent.rule_displayed_name }}</h6>
      <p v-if="ruleContent.rule_title" class="text-muted small mb-3">
        {{ ruleContent.rule_title }}
      </p>

      <div v-for="section in sections" :key="section.key" :data-section="section.key" class="mb-2">
        <div
          class="section-header d-flex align-items-center px-2 py-1 rounded"
          :class="{ 'section-header--collapsed': !isSectionExpanded(section.key) }"
          role="button"
          tabindex="0"
          :aria-expanded="String(isSectionExpanded(section.key))"
          @click="toggleSection(section.key)"
          @keydown.enter="toggleSection(section.key)"
          @keydown.space.prevent="toggleSection(section.key)"
        >
          <b-icon
            :icon="isSectionExpanded(section.key) ? 'chevron-down' : 'chevron-right'"
            class="mr-2 flex-shrink-0"
          />
          <strong class="small">{{ section.label }}</strong>
          <span
            v-if="!isSectionExpanded(section.key)"
            class="section-preview text-muted small ml-2 text-truncate"
          >
            {{ truncate(section.content, 80) }}
          </span>
        </div>
        <div
          v-show="isSectionExpanded(section.key)"
          class="section-body pl-4 pr-2 py-2 small"
          :class="{ 'section-body--focused': section.key === focusedSection }"
        >
          {{ section.content }}
        </div>
      </div>
    </template>

    <div v-else class="p-3 text-center text-muted">
      <b-icon icon="building" class="mb-2" font-scale="1.5" />
      <p class="mb-0">Overall Component</p>
      <p class="small mb-0">
        This comment applies to the component as a whole, not a specific rule.
      </p>
    </div>
  </div>
</template>

<script>
import { SECTION_LABELS } from "../../constants/triageVocabulary";

export default {
  name: "RuleContextPanel",
  props: {
    ruleContent: { type: Object, default: null },
    focusedSection: { type: String, default: null },
  },
  data() {
    return {
      manualToggles: {},
    };
  },
  computed: {
    sections() {
      if (!this.ruleContent) return [];
      return Object.entries(SECTION_LABELS)
        .map(([key, label]) => ({
          key,
          label,
          content: this.ruleContent[`rule_${key}`] || null,
        }))
        .filter((s) => s.content !== null && s.content !== undefined);
    },
  },
  watch: {
    focusedSection() {
      this.manualToggles = {};
    },
  },
  methods: {
    isSectionExpanded(key) {
      if (key in this.manualToggles) return this.manualToggles[key];
      if (this.focusedSection === null) return true;
      return key === this.focusedSection;
    },
    toggleSection(key) {
      this.$set(this.manualToggles, key, !this.isSectionExpanded(key));
    },
    truncate(text, len) {
      if (!text || text.length <= len) return text;
      return text.slice(0, len) + "...";
    },
  },
};
</script>

<style scoped>
.section-header {
  cursor: pointer;
  user-select: none;
}

.section-header:hover {
  background-color: rgba(0, 0, 0, 0.04);
}

.section-header--collapsed {
  opacity: 0.85;
}

.section-body {
  max-height: 400px;
  overflow-y: auto;
  white-space: pre-wrap;
  word-break: break-word;
}

.section-body--focused {
  border-left: 3px solid #007bff;
  padding-left: calc(1.5rem - 3px) !important;
}

.section-preview {
  max-width: 60%;
}
</style>
