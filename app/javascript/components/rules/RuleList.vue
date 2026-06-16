<template>
  <div>
    <!-- Currently opened rules -->
    <p class="mt-0 mb-1 d-flex justify-content-between align-items-center spacing-responsive">
      <strong>{{ navLabels.openRules }}</strong>
      <template v-if="ruleStore.openRuleIds.length > 0">
        <span
          data-test="close-all-rules"
          class="clickable text-primary"
          @click="rulesDeselected(openRules)"
        >
          <b-icon icon="x" class="clickable" />
          close all
        </span>
      </template>
    </p>
    <div v-if="openRules.length === 0">
      <em>{{ navLabels.noRulesSelected }}</em>
    </div>
    <div v-else>
      <div
        v-for="rule in openRules"
        :key="`open-${rule.id}`"
        :class="ruleRowClass(rule)"
        class="d-flex justify-content-between text-responsive"
        @click="ruleSelected(rule)"
      >
        <span>
          <b-icon icon="x" aria-hidden="true" @click.stop="ruleDeselected(rule)" />
          <span v-if="showSRGIdChecked" v-b-tooltip.hover :title="rule.srg_id">
            {{ truncateId(rule.srg_id) }}
          </span>
          <span v-else>{{ formatRuleId(rule.rule_id) }}</span>
        </span>
        <RuleRowIcons :rule="rule" :rule-open="ruleOpen(rule)" />
      </div>
    </div>

    <hr class="mt-2 mb-2" />

    <!-- All project rules -->
    <p
      data-test="all-rules-header"
      class="mt-0 mb-0 d-flex justify-content-between align-items-center spacing-responsive"
    >
      <span>
        <strong>{{ navLabels.allRules }}</strong>
        <span v-if="isFiltered" class="text-muted small ml-1">
          ({{ filteredRules.length }} of {{ allRules.length }})
        </span>
        <span v-else class="text-muted small ml-1">({{ allRules.length }})</span>
        <span
          v-if="isFiltered"
          data-test="inline-clear-filters"
          class="text-primary clickable small ml-1"
          @click="$emit('reset-filters')"
        >
          clear
        </span>
      </span>
      <template v-if="!readOnly">
        <span v-b-modal.create-rule-modal data-test="add-rule-btn" class="text-primary clickable">
          <b-icon v-b-modal.create-rule-modal icon="plus" /> add
        </span>
      </template>
    </p>

    <!-- New rule modal -->
    <NewRuleModalForm :title="navLabels.createNew" :for-duplicate="false" id-prefix="create" />

    <!-- All rules list -->
    <div v-for="rule in filteredRules" :key="`rule-${rule.id}`">
      <div
        :class="ruleRowClass(rule)"
        class="d-flex justify-content-between text-responsive"
        @click="ruleSelected(rule)"
      >
        <span>
          <!-- Expand/collapse toggle for parents with children -->
          <template v-if="nestSatisfiedRulesChecked && rule.satisfies.length > 0">
            <b-icon
              :icon="isParentExpanded(rule.id) ? 'chevron-down' : 'chevron-right'"
              class="tree-toggle mr-1"
              @click="toggleParentExpanded(rule.id, $event)"
            />
          </template>
          <!-- Spacer for leaf nodes to align with parents that have chevrons -->
          <template v-else-if="nestSatisfiedRulesChecked && hasParentRules">
            <span class="tree-toggle-spacer" />
          </template>
          <span v-if="showSRGIdChecked" v-b-tooltip.hover :title="rule.srg_id">
            {{ truncateId(rule.srg_id) }}
          </span>
          <span v-else>
            {{ formatRuleId(rule.rule_id) }}
          </span>
          <!-- Child count badge for collapsed parents -->
          <b-badge
            v-if="nestSatisfiedRulesChecked && rule.satisfies.length > 0"
            variant="secondary"
            pill
            class="ml-1 child-count"
          >
            {{ rule.satisfies.length }}
          </b-badge>
        </span>
        <RuleRowIcons :rule="rule" :rule-open="ruleOpen(rule)" />
      </div>
      <div
        v-if="nestSatisfiedRulesChecked && rule.satisfies.length > 0"
        v-show="isParentExpanded(rule.id)"
        class="nested-children"
      >
        <div
          v-for="satisfies in sortAlsoSatisfies(rule.satisfies)"
          :key="satisfies.id"
          :class="ruleRowClass(satisfies)"
          class="d-flex justify-content-between text-responsive child-row"
          @click="ruleSelected(satisfies)"
        >
          <span>
            <b-icon icon="chevron-right" />
            <span v-b-tooltip.hover :title="satisfies.srg_id">
              {{ truncateId(satisfies.srg_id) }}
            </span>
          </span>
          <RuleRowIcons :rule="satisfies" :rule-open="0" />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import NewRuleModalForm from "./forms/NewRuleModalForm.vue";
import RuleRowIcons from "./RuleRowIcons.vue";
import { NAVIGATOR_LABELS } from "../../constants/terminology";
import { truncateId } from "../../utils/idFormatter";
import { useRuleSelectionStore } from "../../stores/ruleSelection";

export default {
  name: "RuleList",
  components: { NewRuleModalForm, RuleRowIcons },
  props: {
    filteredRules: {
      type: Array,
      required: true,
    },
    allRules: {
      type: Array,
      required: true,
    },
    componentId: {
      type: Number,
      required: true,
    },
    projectPrefix: {
      type: String,
      required: true,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
    nestSatisfiedRulesChecked: {
      type: Boolean,
      default: false,
    },
    showSRGIdChecked: {
      type: Boolean,
      default: false,
    },
    hasActiveFilters: {
      type: Boolean,
      default: false,
    },
  },
  setup() {
    const ruleStore = useRuleSelectionStore();
    return { ruleStore };
  },
  data() {
    return {
      navLabels: NAVIGATOR_LABELS,
      expandedParents: new Set(),
      truncateId,
    };
  },
  computed: {
    hasParentRules() {
      return this.filteredRules.some((r) => r.satisfies && r.satisfies.length > 0);
    },
    openRules() {
      return this.allRules.filter((rule) => this.ruleStore.openRuleIds.includes(rule.id));
    },
    isFiltered() {
      return this.hasActiveFilters;
    },
  },
  methods: {
    ruleSelected(rule) {
      if (!rule.histories) {
        this.$root.$emit("refresh:rule", rule.id);
      }
      this.ruleStore.selectRule(rule.id);
    },
    ruleDeselected(rule) {
      this.ruleStore.deselectRule(rule.id);
    },
    rulesDeselected(rules) {
      rules.forEach((rule) => {
        this.ruleStore.deselectRule(rule.id);
      });
    },
    ruleRowClass(rule) {
      return {
        ruleRow: true,
        clickable: true,
        selectedRuleRow: this.ruleStore.selectedRuleId == rule.id,
      };
    },
    ruleOpen(rule) {
      let count = (rule.comment_summary && rule.comment_summary.open) || 0;
      if (rule.satisfies && rule.satisfies.length > 0) {
        for (const sat of rule.satisfies) {
          const child = this.allRules.find((r) => r.id === sat.id);
          if (child && child.comment_summary) {
            count += child.comment_summary.open || 0;
          }
        }
      }
      return count;
    },
    formatRuleId(id) {
      return `${this.projectPrefix}-${id}`;
    },
    isParentExpanded(ruleId) {
      return this.expandedParents.has(ruleId);
    },
    toggleParentExpanded(ruleId, event) {
      if (event) {
        event.stopPropagation();
      }
      if (this.expandedParents.has(ruleId)) {
        this.expandedParents.delete(ruleId);
      } else {
        this.expandedParents.add(ruleId);
      }
      this.expandedParents = new Set(this.expandedParents);
    },
    sortAlsoSatisfies(rules) {
      return [...rules].sort((a, b) => a.rule_id.localeCompare(b.rule_id));
    },
  },
};
</script>

<style scoped>
.text-responsive {
  font-size: 0.9em;
  font-weight: 500;
}

.spacing-responsive {
  letter-spacing: -0.05em;
}

.ruleRow {
  padding: 0.25em;
}

.ruleRow:hover {
  background: var(--vulcan-overlay-medium);
}

.selectedRuleRow {
  background: var(--vulcan-active-bg);
  border-left: 3px solid var(--vulcan-active-border);
}

.tree-toggle {
  cursor: pointer;
  color: var(--vulcan-secondary);
  transition: transform 0.15s ease;
}

.tree-toggle:hover {
  color: var(--vulcan-primary);
}

.tree-toggle-spacer {
  display: inline-block;
  width: 1em;
  margin-right: 0.25rem;
}

.nested-children {
  margin-left: 1rem;
  border-left: 1px solid var(--vulcan-gray-300);
  padding-left: 0.5rem;
}

.child-row {
  font-size: 0.9em;
  color: var(--vulcan-gray-700);
}

.child-count {
  font-size: 0.75em;
  font-weight: normal;
}

@media (min-width: 1200px) {
  .text-responsive {
    font-size: 1em;
    font-weight: 400;
  }
  .spacing-responsive {
    letter-spacing: 0.01em;
  }
}
</style>
