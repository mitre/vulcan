<template>
  <div class="rule-context-panel">
    <template v-if="ruleContent">
      <h6 class="mb-1 font-weight-bold">{{ ruleDisplayedName }}</h6>
      <p v-if="ruleContent.title" class="text-muted small mb-2">
        {{ ruleContent.title }}
      </p>

      <div v-if="inlineSections.length" class="mb-3">
        <div
          v-for="section in inlineSections"
          :key="section.key"
          :data-section="section.key"
          class="d-flex small mb-1"
        >
          <strong class="mr-2 text-nowrap">{{ section.label }}:</strong>
          <span class="text-muted">{{ section.content }}</span>
        </div>
      </div>

      <div
        v-for="section in collapsibleSections"
        :key="section.key"
        :data-section="section.key"
        class="mb-2"
      >
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
          class="section-body small"
          :class="{ 'section-body--focused': section.key === focusedSection }"
          v-text="section.content"
        />
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
import { STATUS_FIELD_CONFIG, FIELD_LABELS } from "../../composables/ruleFieldConfig";

const INLINE_SECTIONS = new Set(["status", "rule_severity"]);

function fieldLabel(key) {
  return FIELD_LABELS[key] || key;
}

export default {
  name: "RuleContextPanel",
  props: {
    ruleContent: { type: Object, default: null },
    ruleDisplayedName: { type: String, default: null },
    ruleStatus: { type: String, default: null },
    focusedSection: { type: String, default: null },
  },
  data() {
    return {
      manualToggles: {},
    };
  },
  computed: {
    visibleFields() {
      if (!this.ruleContent) return [];
      const config = STATUS_FIELD_CONFIG[this.ruleStatus];
      if (!config) return this.fallbackSections();

      const fields = [];
      const seen = new Set();
      const addFields = (list) => {
        for (const key of list) {
          const normalizedKey = key === "content" ? "check_content" : key;
          if (seen.has(normalizedKey)) continue;
          seen.add(normalizedKey);
          const val = this.ruleContent[normalizedKey];
          if (val === null || val === undefined || val === "") continue;
          fields.push({
            key: normalizedKey,
            label: fieldLabel(normalizedKey),
            content: String(val),
          });
        }
      };

      addFields(config.rule.displayed);
      addFields(config.disa.displayed);
      addFields(config.check.displayed);
      if (config.rule.advancedDisplayed) addFields(config.rule.advancedDisplayed);
      if (config.disa.advancedDisplayed) addFields(config.disa.advancedDisplayed);

      return fields;
    },
    inlineSections() {
      return this.visibleFields.filter((s) => INLINE_SECTIONS.has(s.key));
    },
    collapsibleSections() {
      return this.visibleFields.filter((s) => !INLINE_SECTIONS.has(s.key));
    },
  },
  watch: {
    focusedSection() {
      this.manualToggles = {};
    },
  },
  methods: {
    fallbackSections() {
      if (!this.ruleContent) return [];
      return Object.entries(this.ruleContent)
        .filter(([, v]) => v !== null && v !== undefined && v !== "")
        .map(([key, val]) => ({
          key,
          label: fieldLabel(key),
          content: String(val),
        }));
    },
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
  padding: 0.5rem 0.5rem 0.5rem 2rem;
}

.section-body--focused {
  border-left: 3px solid #007bff;
  padding-left: calc(2rem - 3px);
}

.section-preview {
  max-width: 60%;
}
</style>
