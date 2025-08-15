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
      <h5 class="card-title">Requirements</h5>
      <table class="table table-hover">
        <thead>
          <tr>
            <th class="d-flex">
              <b-form-select v-model="field" :options="ruleFields" />
              <i
                v-if="sortOrder === 'asc'"
                class="mdi mdi-arrow-down-drop-circle float-left"
                aria-hidden="true"
                @click="sortOrder = 'desc'"
              />
              <i
                v-if="sortOrder === 'desc'"
                class="mdi mdi-arrow-up-drop-circle float-left"
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
export default {
  name: "StigRuleList",
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
