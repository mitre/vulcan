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
          <span
            v-b-tooltip.hover
            class="status-dot mr-1"
            role="img"
            :data-status="rule.status"
            :title="rule.status"
            :aria-label="`Status: ${rule.status}`"
          />
          <span v-if="showSRGIdChecked" v-b-tooltip.hover :title="rule.srg_id">
            {{ truncateId(rule.srg_id) }}
          </span>
          <span v-else>{{ formatRuleId(rule.rule_id) }}</span>
        </span>
        <RuleRowIcons
          :rule="rule"
          :rule-open="ruleOpen(rule)"
          :pending-relocation="pendingRelocations[rule.id] || null"
          @open-comments="openComments"
        />
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
          <template v-if="nestSatisfiedRulesChecked && childRules(rule).length > 0">
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
          <span
            v-b-tooltip.hover
            class="status-dot mr-1"
            role="img"
            :data-status="rule.status"
            :title="rule.status"
            :aria-label="`Status: ${rule.status}`"
          />
          <span v-if="showSRGIdChecked" v-b-tooltip.hover :title="rule.srg_id">
            {{ truncateId(rule.srg_id) }}
          </span>
          <span v-else>
            {{ formatRuleId(rule.rule_id) }}
          </span>
          <!-- Child count badge for collapsed parents -->
          <b-badge
            v-if="nestSatisfiedRulesChecked && childRules(rule).length > 0"
            variant="secondary"
            pill
            class="ml-1 child-count"
          >
            {{ childRules(rule).length }}
          </b-badge>
        </span>
        <RuleRowIcons
          :rule="rule"
          :rule-open="ruleOpen(rule)"
          :pending-relocation="pendingRelocations[rule.id] || null"
          @open-comments="openComments"
        />
      </div>
      <div
        v-if="nestSatisfiedRulesChecked && childRules(rule).length > 0"
        v-show="isParentExpanded(rule.id)"
        class="nested-children"
      >
        <div
          v-for="satisfies in sortAlsoSatisfies(childRules(rule))"
          :key="satisfies.id"
          :class="ruleRowClass(satisfies)"
          class="d-flex justify-content-between text-responsive child-row"
          @click="ruleSelected(satisfies)"
        >
          <span>
            <b-icon icon="chevron-right" />
            <!-- Satisfaction refs carry no status — resolve it from the
                 full row so the child dot tells the truth. -->
            <span
              v-b-tooltip.hover
              class="status-dot mr-1"
              role="img"
              :data-status="childStatus(satisfies)"
              :title="childStatus(satisfies) || 'Status unknown'"
              :aria-label="`Status: ${childStatus(satisfies) || 'unknown'}`"
            />
            <span v-b-tooltip.hover :title="satisfies.srg_id">
              {{ truncateId(satisfies.srg_id) }}
            </span>
          </span>
          <RuleRowIcons
            :rule="satisfies"
            :rule-open="0"
            :pending-relocation="pendingRelocations[satisfies.id] || null"
            @open-comments="openComments"
          />
        </div>
      </div>
    </div>

    <!-- Requirement comments, reachable from any row's comment indicator.
         CommentList owns its data; the item rendering is the shared
         CommentItem. Add Comment and Reply both hand off to the HOSTING
         page's composer modal — this list never mounts its own. -->
    <b-modal id="rule-comments-modal" :title="commentsModalTitle" size="lg" scrollable>
      <CommentList
        v-if="commentsRule"
        :component-id="componentId"
        :filter-rule-id="commentsRule.id"
      >
        <template #loading>
          <div class="text-center my-3">
            <b-spinner small label="Loading comments" />
          </div>
        </template>
        <template #error="{ error }">
          <b-alert show variant="danger">
            Comments could not be loaded: {{ error.message }}
          </b-alert>
        </template>
        <template #empty>
          <em>No comments on this requirement.</em>
        </template>
        <template #item="{ comment, updateRow }">
          <div class="mb-2">
            <!-- The inner reply chain emits the parent review ID, not the
                 row — bind the slot-scoped comment so the hosts get the
                 full row identity (same shape the comments table sends). -->
            <CommentItem
              :comment="comment"
              :can-reply="!addCommentDisabled"
              @toggle-reaction="(kind) => toggleCommentReaction(comment, kind, updateRow)"
              @reply="() => onReplyComment(comment)"
            />
          </div>
        </template>
      </CommentList>
      <template #modal-footer>
        <!-- Disabled buttons swallow hover — the wrapping span carries
             the tooltip either way (the toolbar's own pattern). -->
        <span v-b-tooltip.hover :title="addCommentTooltip" class="d-inline-block">
          <b-button
            variant="primary"
            data-test="modal-add-comment"
            :disabled="addCommentDisabled"
            @click="onAddComment"
          >
            <b-icon icon="pencil-square" /> Add Comment
          </b-button>
        </span>
        <b-button variant="secondary" @click="$bvModal.hide('rule-comments-modal')">
          Close
        </b-button>
      </template>
    </b-modal>
  </div>
</template>

<script>
import NewRuleModalForm from "./forms/NewRuleModalForm.vue";
import RuleRowIcons from "./RuleRowIcons.vue";
import CommentList from "../containers/CommentList.vue";
import CommentItem from "../shared/CommentItem.vue";
import { NAVIGATOR_LABELS } from "../../constants/terminology";
import { commentsClosedTooltip } from "../../constants/triageVocabulary";
import { truncateId } from "../../utils/idFormatter";
import { useRuleSelectionStore } from "../../stores/ruleSelection";
import { useCommentReactions } from "../../composables/useCommentReactions";

export default {
  name: "RuleList",
  components: { NewRuleModalForm, RuleRowIcons, CommentList, CommentItem },
  // Component-level "comments closed" gate, provided by the pages that
  // host the sidebar (same tree-scoped contract RuleActionsToolbar uses).
  // Defaults keep tests and isolated mounts green.
  inject: {
    isCommentsClosed: { default: () => () => false },
    getClosedReason: { default: () => () => null },
  },
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
    // Pending relocation markers keyed by rule id — supplied by the
    // page's relocation state so every row variant shows the badge.
    pendingRelocations: {
      type: Object,
      default: () => ({}),
    },
    hasActiveFilters: {
      type: Boolean,
      default: false,
    },
  },
  setup() {
    const ruleStore = useRuleSelectionStore();
    const { toggle: toggleReactionApi } = useCommentReactions();
    return { ruleStore, toggleReactionApi };
  },
  data() {
    return {
      navLabels: NAVIGATOR_LABELS,
      expandedParents: new Set(),
      truncateId,
      // The row whose comments the modal is showing; null until first open.
      commentsRule: null,
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
    commentsModalTitle() {
      return this.commentsRule ? this.formatRuleId(this.commentsRule.rule_id) : "";
    },
    // Mirrors the toolbar's Comment gating: a locked rule blocks (rule
    // scope) and a closed comment phase blocks (component scope).
    addCommentDisabled() {
      return !!(this.commentsRule && this.commentsRule.locked) || this.isCommentsClosed();
    },
    addCommentTooltip() {
      if (this.commentsRule && this.commentsRule.locked) {
        return "Rule is locked — comments are closed for this rule";
      }
      if (this.isCommentsClosed()) {
        return commentsClosedTooltip(this.getClosedReason());
      }
      return "Add a comment on this requirement";
    },
  },
  methods: {
    // satisfies is a Rule-shaped payload key; authored SRG requirement
    // payloads omit it entirely, so default to empty.
    childRules(rule) {
      return rule.satisfies || [];
    },
    // Satisfaction refs are id-only stubs — the child's status lives on
    // its full row in allRules (same lookup ruleOpen uses).
    childStatus(satisfies) {
      const full = this.allRules.find((r) => r.id === satisfies.id);
      return (full && full.status) || null;
    },
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
    openComments(rule) {
      this.commentsRule = rule;
      this.$bvModal.show("rule-comments-modal");
    },
    // Composer entry points: the hosting page owns the composer modal
    // (RulesCodeEditorView / ProjectComponent) — this list only hands the
    // context up and gets out of the way.
    onAddComment() {
      this.$bvModal.hide("rule-comments-modal");
      this.$emit("add-comment", this.commentsRule);
    },
    onReplyComment(row) {
      this.$bvModal.hide("rule-comments-modal");
      this.$emit("reply-comment", row);
    },
    toggleCommentReaction(comment, kind, updateRow) {
      const prev = { ...comment.reactions };
      this.toggleReactionApi(comment.id, kind, prev, (reactions) => {
        updateRow(comment.id, { reactions });
      });
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
