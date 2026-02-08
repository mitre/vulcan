<!-- StigRuleOverview.vue -->
<template>
  <div class="card h-100 w-100">
    <div class="card-header">
      <h5 class="card-title">Requirement Overview</h5>
    </div>
    <div class="card-body">
      <ul class="list-group list-group-flush">
        <li class="list-group-item"><strong>Vuln ID</strong>: {{ selectedRule.vuln_id }}</li>
        <li class="list-group-item"><strong>Rule ID</strong>: {{ selectedRule.rule_id }}</li>
        <li class="list-group-item"><strong>STIG ID</strong>: {{ selectedRule.version }}</li>
        <li class="list-group-item"><strong>SRG ID</strong>: {{ selectedRule.srg_id }}</li>
        <li class="list-group-item">
          <strong>Severity</strong>:
          <span class="badge" :class="severityBgColor">
            {{ SEVERITY_LABELS[selectedRule.rule_severity] || selectedRule.rule_severity }}
          </span>
        </li>
        <li class="list-group-item"><strong>Legacy IDs</strong>: {{ selectedRule.legacy_ids }}</li>
        <li class="list-group-item"><strong>CCI</strong>: {{ selectedRule.ident }}</li>
        <li class="list-group-item">
          <strong>IA Control</strong>: {{ selectedRule.nist_control_family }}
        </li>
      </ul>
    </div>
  </div>
</template>

<script>
import { SEVERITY_LABELS } from "../../constants/terminology";

export default {
  name: "StigRuleOverview",
  props: {
    selectedRule: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      SEVERITY_LABELS,
    };
  },
  computed: {
    severityBgColor() {
      const severity = this.selectedRule.rule_severity;
      if (severity === "high") {
        return "bg-danger text-white";
      } else if (severity === "medium") {
        return "bg-warning text-dark";
      } else {
        return "bg-success text-white";
      }
    },
  },
};
</script>

<style scoped></style>
