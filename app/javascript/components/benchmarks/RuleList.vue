<!-- RuleList.vue - Generic rule list for benchmarks -->
<template>
  <div class="p-3">
    <!-- Filter Section -->
    <div class="mb-3">
      <h5 class="card-title">Filter & Search</h5>
      <input
        v-model="searchText"
        type="text"
        class="form-control form-control-sm mb-2"
        :placeholder="searchPlaceholder"
      />
      <label class="small text-muted mb-1 d-block">Severity</label>
      <b-button-group size="sm" class="d-flex">
        <b-button
          :variant="selectedSeverity === '' ? 'secondary' : 'outline-secondary'"
          @click="setSeverity('')"
        >
          All <b-badge variant="light">{{ rules.length }}</b-badge>
        </b-button>
        <b-button
          :variant="selectedSeverity === 'high' ? 'danger' : 'outline-danger'"
          @click="setSeverity('high')"
        >
          CAT I <b-badge variant="light">{{ high_count }}</b-badge>
        </b-button>
        <b-button
          :variant="selectedSeverity === 'medium' ? 'warning' : 'outline-warning'"
          :class="selectedSeverity === 'medium' ? 'text-dark' : ''"
          @click="setSeverity('medium')"
        >
          CAT II <b-badge variant="light">{{ medium_count }}</b-badge>
        </b-button>
        <b-button
          :variant="selectedSeverity === 'low' ? 'success' : 'outline-success'"
          @click="setSeverity('low')"
        >
          CAT III <b-badge variant="light">{{ low_count }}</b-badge>
        </b-button>
      </b-button-group>
    </div>

    <!-- Table of Rules -->
    <div class="mt-3" style="max-height: 700px; overflow-y: auto">
      <h5 class="card-title">{{ RULE_TERM.plural }}</h5>
      <table class="table table-hover">
        <thead>
          <tr>
            <th class="d-flex">
              <b-form-select v-model="field" :options="fieldOptions" />
              <b-icon
                v-if="sortOrder === 'asc'"
                icon="arrow-down-circle"
                aria-hidden="true"
                @click="sortOrder = 'desc'"
              />
              <b-icon
                v-if="sortOrder === 'desc'"
                icon="arrow-up-circle"
                aria-hidden="true"
                @click="sortOrder = 'asc'"
              />
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="rule in sortedRules"
            :key="rule.id"
            :class="selectedRule && selectedRule.id === rule.id ? 'bg-secondary text-white' : ''"
            @click="selectRule(rule)"
          >
            <td>{{ displayField(rule) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script>
import { RULE_TERM } from "../../constants/terminology";
import { truncateRuleId } from "../../utils/ruleIdFormatter";

export default {
  name: "RuleList",
  props: {
    rules: {
      type: Array,
      required: true,
    },
    initialSelectedRule: {
      type: Object,
      required: true,
    },
    type: {
      type: String,
      required: true,
      validator: (value) => ["stig", "srg"].includes(value),
    },
  },
  data() {
    return {
      RULE_TERM,
      searchText: "",
      selectedSeverity: "",
      low_count: this.filterBySeverity("low").length,
      medium_count: this.filterBySeverity("medium").length,
      high_count: this.filterBySeverity("high").length,
      field: this.type === "srg" ? "srg_id" : "rule_id",
      sortOrder: "asc",
      selectedRule: this.initialSelectedRule,
    };
  },
  computed: {
    searchPlaceholder() {
      const primaryId = this.type === "stig" ? "STIG ID" : "SRG ID";
      return `Search by ${primaryId}, Rule ID, or title`;
    },
    fieldOptions() {
      if (this.type === "srg") {
        return [
          { value: "srg_id", text: "SRG ID" },
          { value: "rule_id", text: "Rule ID" },
        ];
      }
      return [
        { value: "rule_id", text: "Rule ID" },
        { value: "stig_id", text: "STIG ID" },
        { value: "srg_id", text: "SRG ID" },
      ];
    },
    filteredRules() {
      if (this.searchText) {
        return this.rules.filter((rule) => {
          const searchText = this.searchText.toLowerCase();
          return (
            (rule.rule_id && rule.rule_id.toLowerCase().includes(searchText)) ||
            (rule.version && rule.version.toLowerCase().includes(searchText)) ||
            (rule.title && rule.title.toLowerCase().includes(searchText))
          );
        });
      } else if (this.selectedSeverity) {
        return this.filterBySeverity(this.selectedSeverity);
      } else {
        return this.rules;
      }
    },
    sortedRules() {
      const rules = [...this.filteredRules];
      return rules.sort((a, b) => {
        const aVal = this.sortValue(a) || "";
        const bVal = this.sortValue(b) || "";
        const comparison = aVal.localeCompare(bVal);
        return this.sortOrder === "asc" ? comparison : -comparison;
      });
    },
  },
  methods: {
    setSeverity(severity) {
      this.selectedSeverity = severity;
    },
    filterBySeverity(severity) {
      return this.rules.filter((rule) => rule.rule_severity === severity);
    },
    selectRule(rule) {
      this.selectedRule = rule;
      this.$emit("rule-selected", rule);
    },
    sortValue(rule) {
      switch (this.field) {
        case "rule_id":
          return rule.rule_id;
        case "stig_id":
          return rule.version;
        case "srg_id":
          return this.type === "srg" ? rule.version : rule.srg_id;
        default:
          return rule.rule_id;
      }
    },
    displayField(rule) {
      switch (this.field) {
        case "rule_id":
          return truncateRuleId(rule.rule_id);
        case "stig_id":
          return rule.version;
        case "srg_id":
          return this.type === "srg" ? rule.version : rule.srg_id;
        default:
          return rule.rule_id;
      }
    },
  },
};
</script>

<style scoped></style>
