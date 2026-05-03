<!-- StigRuleList.vue -->
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
            placeholder="Search Rule by STIG ID or SRG ID"
          /><br />
          <span id="stig-severity-filter-label" class="small text-muted mb-1 d-block"
            >Severity</span
          >
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
        </p>
      </div>
    </div>

    <!-- Table of Rules -->
    <div class="mt-3" style="max-height: 700px; overflow-y: auto">
      <h5 class="card-title">Requirements</h5>
      <table class="table table-hover">
        <thead>
          <tr>
            <th class="d-flex">
              <FilterDropdown
                v-model="field"
                :options="ruleFieldOptions"
                aria-label="Filter rules by ID type"
              />
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
            <td>{{ field === "SRG ID" ? rule.srg_id : rule.version }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script>
import FilterDropdown from "../shared/FilterDropdown.vue";

export default {
  name: "StigRuleList",
  components: { FilterDropdown },
  props: {
    rules: {
      type: Array,
      required: true,
    },
    initialSelectedRule: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      searchText: "",
      selectedSeverity: "",
      low_count: this.filterBySeverity("low").length,
      medium_count: this.filterBySeverity("medium").length,
      high_count: this.filterBySeverity("high").length,
      ruleFields: ["SRG ID", "STIG ID"],
      field: "SRG ID",
      sortOrder: "asc",
      selectedRule: this.initialSelectedRule,
    };
  },
  computed: {
    ruleFieldOptions() {
      return this.ruleFields.map((f) => ({ value: f, text: f }));
    },
    filteredRules() {
      if (this.searchText) {
        return this.rules.filter((rule) => {
          const searchText = this.searchText.toLowerCase();
          return (
            rule.srg_id.toLowerCase().includes(searchText) ||
            rule.version.toLowerCase().includes(searchText)
          );
        });
      } else if (this.selectedSeverity) {
        return this.filterBySeverity(this.selectedSeverity);
      } else {
        return this.rules;
      }
    },
    sortedRules() {
      const rules = this.filteredRules;
      return rules.sort((a, b) => {
        if (this.field === "SRG ID") {
          return this.sortOrder === "asc"
            ? a.srg_id.localeCompare(b.srg_id)
            : b.srg_id.localeCompare(a.srg_id);
        } else {
          return this.sortOrder === "asc"
            ? a.version.localeCompare(b.version)
            : b.version.localeCompare(a.version);
        }
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
  },
};
</script>

<style scoped>
#stig-rule-table-container {
  max-height: 10px;
  overflow-y: auto;
}
</style>
