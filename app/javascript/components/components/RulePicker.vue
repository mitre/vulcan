<template>
  <div>
    <b-form-input
      v-model="query"
      :placeholder="msg.rulePickerPlaceholder"
      debounce="200"
      :aria-label="msg.rulePickerAria"
      size="sm"
      class="mb-2"
    />
    <div v-if="loading" class="text-muted small">
      <b-spinner small />
      Loading {{ nounPlural }}…
    </div>
    <!-- Sonar Web:S6842: <li role="button"> assigns an
         interactive role to a non-interactive element. The semantically
         correct ARIA pattern for picking-from-a-list is <ul role="listbox">
         + <li role="option" aria-selected>. role="option" is allowed on
         <li> inside a listbox per ARIA 1.2. -->
    <ul
      v-else
      role="listbox"
      class="list-unstyled mb-0"
      style="max-height: 280px; overflow-y: auto"
    >
      <li v-if="filteredRules.length === 0" class="text-muted small font-italic px-1">
        No matching {{ nounPlural }} in this component.
      </li>
      <li
        v-for="rule in filteredRules"
        :key="rule.id"
        :data-test="`target-rule-${rule.id}`"
        class="border rounded p-2 mb-1 rule-candidate"
        :class="ruleItemClasses(rule.id)"
        role="option"
        :aria-selected="Number(selectedRuleId) === rule.id"
        tabindex="0"
        @click="$emit('selected', rule.id)"
        @keydown.enter="$emit('selected', rule.id)"
      >
        <div>
          <strong>{{ rule.displayed_name || `#${rule.rule_id}` }}</strong>
          <span
            v-if="relationshipLabel(rule.id)"
            data-test="relationship-badge"
            class="badge ml-1"
            :class="relationshipLabel(rule.id) === 'Parent' ? 'badge-primary' : 'badge-secondary'"
            >{{ relationshipLabel(rule.id) }}</span
          >
          <small v-if="rule.title" class="text-muted ml-2">{{ truncate(rule.title, 80) }}</small>
        </div>
      </li>
    </ul>
  </div>
</template>

<script>
import { getRulesPicker } from "../../api/rulesApi";
import { messageLabels, ruleTerm } from "../../constants/terminology";
import { ruleArray } from "../../utils/ruleArray";

// Picker for a target rule scoped to one component: the "move to rule"
// admin action, per-comment addressed_by, and the bulk target modal.
// Excludes the given rules so the user doesn't pick a rule the comment is
// already on (single source) or any selected comment's own rule (bulk).
export default {
  name: "RulePicker",
  // Component kind from the triage root (TriageSplitView / ComponentComments);
  // default keeps tests and isolated mounts green.
  inject: {
    injectedDocumentType: { default: "stig" },
  },
  props: {
    componentId: { type: [Number, String], required: true },
    excludeRuleIds: { type: Array, required: true },
    selectedRuleId: { type: [Number, String], default: null },
  },
  data() {
    return {
      rules: [],
      query: "",
      loading: false,
    };
  },
  computed: {
    msg() {
      return messageLabels(this.injectedDocumentType);
    },
    nounPlural() {
      return ruleTerm(this.injectedDocumentType).plural.toLowerCase();
    },
    sourceRule() {
      // Parent/Child relationship badges only make sense relative to ONE
      // source rule (per-comment triage, move-to-rule). A bulk selection
      // excludes many rules and has no single source — no badges there.
      if (this.excludeRuleIds.length !== 1) return null;
      return this.rules.find((r) => r.id === Number(this.excludeRuleIds[0])) || null;
    },
    parentRuleIds() {
      return new Set(ruleArray(this.sourceRule, "satisfied_by").map((r) => r.id));
    },
    childRuleIds() {
      return new Set(ruleArray(this.sourceRule, "satisfies").map((r) => r.id));
    },
    filteredRules() {
      const exclude = new Set(this.excludeRuleIds.map(Number));
      const q = this.query.toLowerCase().trim();
      const parents = this.parentRuleIds;
      return this.rules
        .filter((r) => !exclude.has(r.id))
        .filter((r) => {
          if (!q) return true;
          const name = (r.displayed_name || r.rule_id || "").toLowerCase();
          const title = (r.title || "").toLowerCase();
          return name.includes(q) || title.includes(q);
        })
        .sort((a, b) => {
          const aParent = parents.has(a.id) ? 0 : 1;
          const bParent = parents.has(b.id) ? 0 : 1;
          return aParent - bParent;
        })
        .slice(0, 50);
    },
  },
  mounted() {
    this.fetchRules();
  },
  methods: {
    fetchRules() {
      this.loading = true;
      getRulesPicker(this.componentId)
        .then((res) => {
          // ComponentBlueprint :show / :editor view exposes a `rules` array
          // shaped at minimum: { id, rule_id, displayed_name?, title? }
          this.rules = res.data.rules || [];
        })
        .catch(() => {
          this.rules = [];
        })
        .finally(() => {
          this.loading = false;
        });
    },
    ruleItemClasses(ruleId) {
      const selected = Number(this.selectedRuleId) === ruleId;
      const rel = this.relationshipLabel(ruleId);
      return {
        "border-primary bg-light": selected,
        "rule-candidate--parent": rel === "Parent" && !selected,
        "rule-candidate--child": rel === "Child" && !selected,
      };
    },
    relationshipLabel(ruleId) {
      if (this.parentRuleIds.has(ruleId)) return "Parent";
      if (this.childRuleIds.has(ruleId)) return "Child";
      return null;
    },
    truncate(s, n) {
      return s && s.length > n ? `${s.slice(0, n)}…` : s;
    },
  },
};
</script>

<style scoped>
.rule-candidate--parent {
  border-left: 3px solid var(--triage-addressed-by, #6366f1) !important;
  background-color: var(--triage-addressed-by-tint, rgba(99, 102, 241, 0.06));
}

.rule-candidate--child {
  border-left: 3px solid var(--vulcan-text-muted, #6c757d) !important;
  background-color: var(--vulcan-secondary-tint);
}
</style>
