<template>
  <main role="main" class="container-fluid">
    <h1>{{ stig.title }} :: {{ stig.version }}</h1>
    <h6 class="card-subtitle text-muted mb-2">Benchmark Date: {{ stig.benchmark_date }}</h6>
    <br />
    <hr />
    <div class="row responsive w-100">
      <!-- Left Sidebar -->
      <aside class="col-md-3 w-100">
        <StigRuleList
          :rules="stig.stig_rules"
          :initial-selected-rule="selectedRule"
          @rule-selected="onRuleSelected"
        />
      </aside>
      <!-- Middle Section -->
      <main class="col-md-6 w-100">
        <StigRuleDetails :selected-rule="selectedRule" />
      </main>
      <!-- Right Sidebar -->
      <aside class="col-md-3 w-100">
        <StigRuleOverview :selected-rule="selectedRule" />
      </aside>
    </div>
  </main>
</template>

<script>
import StigRuleList from "./StigRuleList.vue";
import StigRuleDetails from "./StigRuleDetails.vue";
import StigRuleOverview from "./StigRuleOverview.vue";
export default {
  name: "Stigs",
  components: { StigRuleList, StigRuleDetails, StigRuleOverview },
  props: {
    stig: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      selectedRule: this.initialSelectedRule(),
    };
  },
  methods: {
    onRuleSelected(rule) {
      this.selectedRule = rule;
    },
    initialSelectedRule() {
      let rules = this.stig.stig_rules;
      return rules.sort((a, b) => a.srg_id.localeCompare(b.srg_id))[0];
    },
  },
};
</script>

<style scoped></style>
