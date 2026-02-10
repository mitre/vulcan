<!-- RuleOverview.vue - Generic rule overview for benchmarks -->
<template>
  <div class="card h-100 w-100">
    <div class="card-header">
      <h5 class="card-title">{{ RULE_TERM.singular }} Overview</h5>
    </div>
    <div v-if="!selectedRule" class="card-body text-center text-muted py-5">
      <p>Select a {{ RULE_TERM.singular.toLowerCase() }} to view overview.</p>
    </div>
    <div v-else class="card-body">
      <ul class="list-group list-group-flush">
        <!-- ============================================ -->
        <!-- STIG MODE: Rule ID, STIG ID, → SRG ID       -->
        <!-- SRG MODE:  SRG ID, Rule ID                   -->
        <!-- ============================================ -->

        <!-- SRG mode: SRG ID first (from version column) -->
        <li v-if="type === 'srg'" class="list-group-item">
          <strong>SRG ID</strong>: {{ selectedRule.version }}
        </li>

        <!-- Rule ID (both modes, with truncation + expand) -->
        <li class="list-group-item" data-testid="rule-id">
          <strong>Rule ID</strong>:
          <button
            type="button"
            data-testid="rule-id-toggle"
            tabindex="0"
            class="btn btn-link p-0 border-0 text-primary align-baseline"
            @click="showFullRuleId = !showFullRuleId"
            @keydown.enter="showFullRuleId = !showFullRuleId"
            @keydown.space.prevent="showFullRuleId = !showFullRuleId"
          >
            {{ showFullRuleId ? selectedRule.rule_id : truncatedRuleId }}
          </button>
        </li>

        <!-- STIG/Component mode: STIG ID (from version column) -->
        <li v-if="type === 'stig' || type === 'component'" class="list-group-item">
          <strong>STIG ID</strong>: {{ selectedRule.version }}
        </li>

        <!-- STIG/Component mode: → SRG ID (from srg_id column) -->
        <li
          v-if="(type === 'stig' || type === 'component') && selectedRule.srg_id"
          class="list-group-item"
        >
          <strong>&rarr; SRG ID</strong>: {{ selectedRule.srg_id }}
        </li>

        <!-- Legacy toggle (collapsed by default) -->
        <li v-if="hasLegacyFields" class="list-group-item">
          <button
            type="button"
            data-testid="legacy-toggle"
            tabindex="0"
            class="btn btn-link p-0 border-0 text-muted small align-baseline"
            @click="showLegacyIds = !showLegacyIds"
            @keydown.enter="showLegacyIds = !showLegacyIds"
            @keydown.space.prevent="showLegacyIds = !showLegacyIds"
          >
            {{ showLegacyIds ? "▾" : "▸" }} Legacy IDs
          </button>
          <div v-if="showLegacyIds" class="mt-1 ml-3">
            <div v-if="(type === 'stig' || type === 'component') && selectedRule.vuln_id">
              <strong>Vuln ID</strong>: {{ selectedRule.vuln_id }}
            </div>
            <div v-if="selectedRule.legacy_ids">
              <strong>Legacy IDs</strong>: {{ selectedRule.legacy_ids }}
            </div>
          </div>
        </li>

        <!-- Severity (both types) -->
        <li class="list-group-item">
          <strong>Severity</strong>:
          <span class="border px-2 py-1 rounded" :class="severityBorderColor">
            <span :class="severityTextColor" class="font-weight-bold">
              {{ SEVERITY_LABELS[selectedRule.rule_severity] || selectedRule.rule_severity }}
            </span>
          </span>
        </li>

        <!-- CCI (both types) -->
        <li v-if="selectedRule.ident" class="list-group-item">
          <strong>CCI</strong>: {{ selectedRule.ident }}
        </li>

        <!-- IA Control (both types) -->
        <li v-if="selectedRule.nist_control_family" class="list-group-item">
          <strong>IA Control</strong>: {{ selectedRule.nist_control_family }}
        </li>

        <!-- MITRE ATT&CK Techniques (if present in ident) -->
        <li v-if="mitreTechniques.length > 0" class="list-group-item">
          <strong>ATT&CK Techniques</strong>:
          <span v-for="(tech, idx) in mitreTechniques" :key="tech">
            <a
              :href="`https://attack.mitre.org/techniques/${tech.replace('.', '/')}`"
              target="_blank"
              rel="noopener noreferrer"
              class="text-decoration-none"
              >{{ tech }}</a
            >
            <span v-if="idx < mitreTechniques.length - 1">, </span>
          </span>
        </li>

        <!-- CIS Controls (if present in ident) -->
        <li v-if="cisControls.length > 0" class="list-group-item">
          <strong>CIS Controls</strong>:
          <span v-for="(control, idx) in cisControls" :key="control">
            <a
              href="https://www.cisecurity.org/controls"
              target="_blank"
              rel="noopener noreferrer"
              class="text-decoration-none"
              >{{ control }}</a
            >
            <span v-if="idx < cisControls.length - 1">, </span>
          </span>
        </li>
      </ul>
    </div>
  </div>
</template>

<script>
import { RULE_TERM, SEVERITY_LABELS } from "../../constants/terminology";
import { parseMitreAttack, parseCisControls } from "../../utils/identParser";
import { truncateRuleId } from "../../utils/ruleIdFormatter";

export default {
  name: "RuleOverview",
  props: {
    type: {
      type: String,
      required: true,
      validator: (value) => ["stig", "srg", "component"].includes(value),
    },
    selectedRule: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      RULE_TERM,
      SEVERITY_LABELS,
      showFullRuleId: false,
      showLegacyIds: false,
    };
  },
  computed: {
    truncatedRuleId() {
      return truncateRuleId(this.selectedRule?.rule_id);
    },
    hasLegacyFields() {
      if (!this.selectedRule) return false;
      if (this.type === "stig" || this.type === "component") {
        return !!(this.selectedRule.vuln_id || this.selectedRule.legacy_ids);
      }
      return !!this.selectedRule.legacy_ids;
    },
    severityBorderColor() {
      const severity = this.selectedRule.rule_severity;
      if (severity === "high") {
        return "border-danger";
      } else if (severity === "medium") {
        return "border-warning";
      } else {
        return "border-success";
      }
    },
    severityTextColor() {
      const severity = this.selectedRule.rule_severity;
      if (severity === "high") {
        return "text-danger";
      } else if (severity === "medium") {
        return "text-warning";
      } else {
        return "text-success";
      }
    },
    mitreTechniques() {
      return parseMitreAttack(this.selectedRule.ident);
    },
    cisControls() {
      return parseCisControls(this.selectedRule.ident);
    },
  },
  watch: {
    selectedRule() {
      this.showFullRuleId = false;
      this.showLegacyIds = false;
    },
  },
};
</script>
