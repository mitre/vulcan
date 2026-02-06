<!-- RuleList.vue - Generic rule list for benchmarks -->
<template>
  <div class="p-3">
    <!-- Filter Section -->
    <div class="mb-3">
      <h5 class="card-title">Filter & Search</h5>
      <div class="input-group">
        <p class="card-text">
          <strong>Search</strong><br />
          <input
            v-model="searchText"
            type="text"
            class="form-control"
            :placeholder="searchPlaceholder"
          /><br />
          <strong>Filter by Severity</strong><br />
          <button class="btn btn-danger mb-2" @click="setSeverity('high')">
            High <span class="badge badge-light">{{ high_count }}</span>
          </button>
          <button class="btn btn-warning mb-2" @click="setSeverity('medium')">
            Medium <span class="badge badge-light">{{ medium_count }}</span>
          </button>
          <button class="btn btn-success mb-2" @click="setSeverity('low')">
            Low <span class="badge badge-light">{{ low_count }}</span>
          </button>
          <button class="btn btn-info mb-2" @click="setSeverity('')">
            All <span class="badge badge-light">{{ rules.length }}</span>
          </button>
        </p>
      </div>
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
