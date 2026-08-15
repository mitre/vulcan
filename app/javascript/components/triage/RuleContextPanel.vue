<template>
  <div class="rule-context-panel">
    <template v-if="ruleContent">
      <div class="rule-context-header mb-1">
        <h6 class="mb-0 font-weight-bold">
          <b-icon
            v-if="ruleContent.locked"
            icon="lock"
            class="text-warning mr-1"
            aria-hidden="true"
          />
          {{ ruleDisplayedName }}
          <b-badge
            v-if="parentRuleDisplayedName && !satisfiedByParents.length"
            variant="info"
            pill
            class="ml-1 small"
            data-testid="child-indicator"
          >
            child of {{ parentRuleDisplayedName }}
          </b-badge>
          <b-badge
            v-if="ruleContent.locked"
            variant="warning"
            pill
            class="ml-1 small"
            data-testid="locked-indicator"
          >
            Locked
          </b-badge>
        </h6>
      </div>
      <div class="d-flex align-items-center mb-2" data-testid="context-toolbar">
        <b-form-checkbox
          :checked="contextMode === 'commented'"
          switch
          size="sm"
          class="flex-shrink-0"
          data-testid="context-mode-toggle"
          @change="$emit('update:contextMode', $event ? 'commented' : 'all')"
        >
          <small class="text-muted">
            Focus Section
            <InfoTooltip text="Show only the section this comment targets, or expand all fields" />
          </small>
        </b-form-checkbox>
        <b-form-checkbox
          v-model="showAdvanced"
          switch
          size="sm"
          class="ml-3 flex-shrink-0"
          data-testid="advanced-fields-toggle"
        >
          <small class="text-muted">
            Advanced
            <InfoTooltip text="Show additional metadata fields (version, weight, identifiers)" />
          </small>
        </b-form-checkbox>
        <b-button
          v-b-tooltip.hover
          size="sm"
          variant="link"
          class="p-0 ml-auto text-muted"
          :title="allSectionsExpanded ? 'Collapse all sections' : 'Expand all sections'"
          data-testid="toggle-sections"
          @click="toggleAllSections"
        >
          <b-icon :icon="allSectionsExpanded ? 'arrows-collapse' : 'arrows-expand'" />
        </b-button>
      </div>
      <hr class="rule-context-divider mt-4 mb-2" />

      <SatisfiedByIndicator v-if="satisfiedByParents.length" :parent-rules="satisfiedByParents">
        This {{ contextNoun }} is covered by its parent — content is edited there.
        <template #actions>
          <a
            v-for="parent in satisfiedByParents"
            :key="'triage-nav-' + parent.id"
            :href="editorLinkFor(parent)"
            target="_blank"
            rel="noopener"
            class="btn btn-sm btn-outline-info"
            data-testid="triage-go-to-parent"
          >
            Go to {{ parent.component_prefix }}-{{ parent.rule_id }} →
          </a>
        </template>
      </SatisfiedByIndicator>

      <p
        v-if="ruleContent.title"
        data-testid="rule-title"
        class="text-muted mb-2"
        :class="{ 'rule-title--overall-focused': focusedSection === null }"
      >
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
        class="mb-3"
      >
        <div
          class="section-header d-flex align-items-center px-2 py-1 rounded"
          :class="{ 'section-header--collapsed': !isSectionExpanded(section.key) }"
          role="button"
          tabindex="0"
          :aria-expanded="String(isSectionExpanded(section.key))"
          :aria-label="'Toggle ' + section.label + ' section'"
          @click="toggleSection(section.key)"
          @keydown.enter="toggleSection(section.key)"
          @keydown.space.prevent="toggleSection(section.key)"
        >
          <b-icon
            :icon="isSectionExpanded(section.key) ? 'chevron-down' : 'chevron-right'"
            class="mr-2 flex-shrink-0"
          />
          <span class="section-title text-nowrap">{{ section.label }}</span>
          <b-badge
            v-if="sectionCount(section.key) > 0"
            variant="secondary"
            pill
            class="comment-count-badge"
            >{{ sectionCount(section.key) }}</b-badge
          >
          <span
            v-if="!isSectionExpanded(section.key)"
            class="section-preview text-muted small ml-2 text-truncate"
            :title="section.content"
          >
            {{ section.content }}
          </span>
        </div>
        <div
          v-show="isSectionExpanded(section.key)"
          class="section-body"
          :class="{ 'section-body--focused': section.key === focusedSection }"
          v-text="section.content"
        />
      </div>
    </template>

    <div v-else class="p-3 text-center text-muted">
      <b-icon icon="building" class="mb-2" font-scale="1.5" />
      <p class="mb-0">Overall Component</p>
      <p class="small mb-0">
        This comment applies to the component as a whole, not a specific {{ contextNoun }}.
      </p>
    </div>
  </div>
</template>

<script>
import { FIELD_LABELS, FIELD_DISPLAY_ORDER } from "../../composables/ruleFieldConfig";
import { buildFieldSets } from "../../composables/fieldStateConfig";
import { ruleArray } from "../../utils/ruleArray";
import { ruleTerm } from "../../constants/terminology";
import InfoTooltip from "../shared/InfoTooltip.vue";
import SatisfiedByIndicator from "../shared/SatisfiedByIndicator.vue";

const INLINE_SECTIONS = new Set(["status", "rule_severity"]);

function fieldLabel(key) {
  return FIELD_LABELS[key] || key;
}

export default {
  name: "RuleContextPanel",
  components: { InfoTooltip, SatisfiedByIndicator },
  props: {
    ruleContent: { type: Object, default: null },
    ruleDisplayedName: { type: String, default: null },
    parentRuleDisplayedName: { type: String, default: null },
    componentId: { type: [Number, String], default: null },
    ruleStatus: { type: String, default: null },
    // The triage view threads the real component kind down to here;
    // "stig" stays the default for callers that predate the threading.
    documentType: {
      type: String,
      default: "stig",
      validator: (value) => ["stig", "srg"].includes(value),
    },
    focusedSection: { type: String, default: null },
    contextMode: {
      type: String,
      default: "all",
      validator: (v) => ["commented", "all"].includes(v),
    },
    commentedSections: { type: Array, default: () => [] },
    sectionCommentCounts: { type: Object, default: () => ({}) },
  },
  data() {
    return {
      manualToggles: {},
      showAdvanced: false,
    };
  },
  computed: {
    contextNoun() {
      return ruleTerm(this.documentType).singular.toLowerCase();
    },
    commentedSectionsSet() {
      return new Set(this.commentedSections);
    },
    satisfiedByParents() {
      return ruleArray(this.ruleContent, "satisfied_by");
    },
    visibleFields() {
      if (!this.ruleContent) return [];

      // The panel shows what the config declares for this kind/status/tier
      // (the Advanced toggle is the interim publisher-tier switch). An
      // unknown status falls back to showing every populated field.
      let sets;
      try {
        sets = buildFieldSets({
          documentType: this.documentType,
          status: this.ruleStatus,
          tier: this.showAdvanced ? "publisher" : "author",
        });
      } catch {
        return this.fallbackSections();
      }

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

      addFields(sets.rule.displayed);
      addFields(sets.disa.displayed);
      addFields(sets.check.displayed);

      fields.sort((a, b) => {
        const idxA = FIELD_DISPLAY_ORDER.indexOf(a.key);
        const idxB = FIELD_DISPLAY_ORDER.indexOf(b.key);
        return (idxA === -1 ? 999 : idxA) - (idxB === -1 ? 999 : idxB);
      });

      if (this.contextMode === "commented" && this.commentedSectionsSet.size > 0) {
        return fields.filter((f) => this.commentedSectionsSet.has(f.key));
      }
      return fields;
    },
    inlineSections() {
      return this.visibleFields.filter((s) => INLINE_SECTIONS.has(s.key));
    },
    collapsibleSections() {
      return this.visibleFields.filter((s) => !INLINE_SECTIONS.has(s.key));
    },
    allSectionsExpanded() {
      return this.collapsibleSections.every((s) => this.isSectionExpanded(s.key));
    },
  },
  watch: {
    focusedSection() {
      this.manualToggles = {};
    },
  },
  methods: {
    editorLinkFor(parent) {
      return `/components/${this.componentId}#/rules/${parent.id}`;
    },
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
    toggleAllSections() {
      const expand = !this.allSectionsExpanded;
      for (const s of this.collapsibleSections) {
        this.$set(this.manualToggles, s.key, expand);
      }
    },
    sectionCount(key) {
      return this.sectionCommentCounts[key] || 0;
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
  background-color: var(--vulcan-hover-bg-light);
}

.rule-context-header {
  flex-wrap: wrap;
  gap: 0.25rem;
}

.rule-context-divider {
  border-top: 1px solid var(--vulcan-divider);
}

.section-title {
  font-weight: 700;
  font-size: 0.9rem;
}

.comment-count-badge {
  position: relative;
  top: -0.6em;
  font-size: 0.6rem;
  margin-left: 0.1em;
  vertical-align: super;
}

.section-header--collapsed {
  opacity: 0.75;
}

.section-header--collapsed .section-preview {
  opacity: 1;
  color: var(--vulcan-text-muted);
}

.section-body {
  max-height: 400px;
  overflow-y: auto;
  white-space: pre-wrap;
  word-break: break-word;
  padding: 0.5rem 0.5rem 0.5rem 2rem;
}

.section-body--focused {
  border-left: 3px solid var(--vulcan-active-border);
  padding-left: calc(2rem - 3px);
  background-color: var(--vulcan-focus-tint);
  border-radius: 0 0.25rem 0.25rem 0;
}

/* Overall-focused indicator on the rule title — fires when the active
 * comment targets the whole requirement (section=null). Intentionally
 * lighter than section-body--focused (no left border, no padding shift)
 * so the two indicators don't compete when both are visible. */
.rule-title--overall-focused {
  background-color: var(--vulcan-focus-tint);
  padding: 0.35rem 0.5rem;
  border-radius: 0.25rem;
  border-left: 2px solid var(--vulcan-info);
}

.section-preview {
  max-width: 60%;
}
</style>
