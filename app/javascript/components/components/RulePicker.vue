<template>
  <div>
    <b-form-input
      v-model="query"
      placeholder="Search by rule ID or title..."
      debounce="200"
      aria-label="Search target rule"
      size="sm"
      class="mb-2"
    />
    <div v-if="loading" class="text-muted small">
      <b-spinner small />
      Loading rules…
    </div>
    <!-- PR-717 .bpy — Sonar Web:S6842: <li role="button"> assigns an
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
        No matching rules in this component.
      </li>
      <li
        v-for="rule in filteredRules"
        :key="rule.id"
        :data-test="`target-rule-${rule.id}`"
        class="border rounded p-2 mb-1 rule-candidate"
        :class="{ 'border-primary bg-light': Number(selectedRuleId) === rule.id }"
        role="option"
        :aria-selected="Number(selectedRuleId) === rule.id"
        tabindex="0"
        @click="$emit('selected', rule.id)"
        @keydown.enter="$emit('selected', rule.id)"
      >
        <div>
          <strong>{{ rule.displayed_name || `#${rule.rule_id}` }}</strong>
          <small v-if="rule.title" class="text-muted ml-2">{{ truncate(rule.title, 80) }}</small>
        </div>
      </li>
    </ul>
  </div>
</template>

<script>
import axios from "axios";

// Picker for the "move to rule" admin action on the triage modal. Scoped
// to the same component as the source review (server enforces same-component
// via the move_to_rule controller action). Excludes the source rule so the
// admin doesn't accidentally pick the rule the comment is already on.
export default {
  name: "RulePicker",
  props: {
    componentId: { type: [Number, String], required: true },
    excludeRuleId: { type: [Number, String], required: true },
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
    filteredRules() {
      const exclude = Number(this.excludeRuleId);
      const q = this.query.toLowerCase().trim();
      return this.rules
        .filter((r) => r.id !== exclude)
        .filter((r) => {
          if (!q) return true;
          const name = (r.displayed_name || r.rule_id || "").toLowerCase();
          const title = (r.title || "").toLowerCase();
          return name.includes(q) || title.includes(q);
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
      axios
        .get(`/components/${this.componentId}.json`)
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
    truncate(s, n) {
      return s && s.length > n ? `${s.slice(0, n)}…` : s;
    },
  },
};
</script>
