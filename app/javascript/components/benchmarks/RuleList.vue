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
      <label id="severity-filter-label" class="small text-muted mb-1 d-block">Severity</label>
      <b-button-group size="sm" vertical class="w-100">
        <b-button
          :variant="selectedSeverity === '' ? 'secondary' : 'outline-secondary'"
          class="d-flex justify-content-between align-items-center"
          @click="setSeverity('')"
        >
          <span>All</span> <b-badge variant="light">{{ rules.length }}</b-badge>
        </b-button>
        <b-button
          :variant="selectedSeverity === 'high' ? 'danger' : 'outline-danger'"
          class="d-flex justify-content-between align-items-center"
          @click="setSeverity('high')"
        >
          <span>CAT I</span> <b-badge variant="light">{{ high_count }}</b-badge>
        </b-button>
        <b-button
          :variant="selectedSeverity === 'medium' ? 'warning' : 'outline-warning'"
          :class="[
            'd-flex justify-content-between align-items-center',
            selectedSeverity === 'medium' ? 'text-dark' : '',
          ]"
          @click="setSeverity('medium')"
        >
          <span>CAT II</span> <b-badge variant="light">{{ medium_count }}</b-badge>
        </b-button>
        <b-button
          :variant="selectedSeverity === 'low' ? 'success' : 'outline-success'"
          class="d-flex justify-content-between align-items-center"
          @click="setSeverity('low')"
        >
          <span>CAT III</span> <b-badge variant="light">{{ low_count }}</b-badge>
        </b-button>
      </b-button-group>
    </div>

    <!-- Table of Rules -->
    <div ref="ruleListContainer" class="mt-3" style="max-height: 700px; overflow-y: auto">
      <h5 class="card-title">{{ RULE_TERM.plural }}</h5>
      <table class="table table-hover" role="listbox" :aria-label="RULE_TERM.plural">
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
        <tbody @keydown="handleKeydown">
          <tr
            v-for="(rule, index) in sortedRules"
            :key="rule.id"
            :class="rowClass(rule, index)"
            :tabindex="index === focusedIndex || (focusedIndex === -1 && index === 0) ? 0 : -1"
            role="option"
            :aria-selected="selectedRule && selectedRule.id === rule.id"
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
      validator: (value) => ["stig", "srg", "component"].includes(value),
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
      focusedIndex: -1,
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
    rowClass(rule, index) {
      if (this.selectedRule && this.selectedRule.id === rule.id) {
        return "bg-secondary text-white";
      }
      if (index === this.focusedIndex) {
        return "bg-light";
      }
      return "";
    },
    handleKeydown(event) {
      const len = this.sortedRules.length;
      if (!len) return;

      if (event.key === "ArrowDown" || event.key === "ArrowUp") {
        event.preventDefault();
        const start = this.focusedIndex >= 0 ? this.focusedIndex : -1;
        if (event.key === "ArrowDown") {
          this.focusedIndex = start < len - 1 ? start + 1 : 0;
        } else {
          this.focusedIndex = start > 0 ? start - 1 : len - 1;
        }
        this.$nextTick(() => {
          const container = this.$refs.ruleListContainer;
          if (!container) return;
          const rows = container.querySelectorAll("tr[role='option']");
          if (rows[this.focusedIndex]) {
            rows[this.focusedIndex].focus();
            if (rows[this.focusedIndex].scrollIntoView) {
              rows[this.focusedIndex].scrollIntoView({ block: "nearest" });
            }
          }
        });
      } else if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        if (this.focusedIndex >= 0 && this.focusedIndex < len) {
          this.selectRule(this.sortedRules[this.focusedIndex]);
        }
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
