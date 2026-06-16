<template>
  <b-modal
    id="also-satisfies-modal"
    :title="`Also Satisfies (${filteredSelectRules.length} available)`"
    centered
    size="lg"
    @ok="addMultipleSatisfiedRules"
    @hidden="clearSelectedRules"
  >
    <b-form-checkbox v-model="showRuleId" class="mb-2" switch size="sm">
      Show Rule IDs instead of SRG IDs
    </b-form-checkbox>
    <b-form-group :label="msg.satisfiesPrompt">
      <multiselect
        v-model="selectedRuleIds"
        :options="filteredSelectRules"
        :multiple="true"
        :close-on-select="false"
        :clear-on-select="false"
        :preserve-search="true"
        :placeholder="msg.satisfiesPlaceholder"
        label="text"
        track-by="value"
        :preselect-first="false"
      >
        <template slot="selection" slot-scope="{ values, isOpen }">
          <span v-if="values.length && !isOpen" class="multiselect__single">
            {{ selectedCountLabel(values.length) }}
          </span>
        </template>
      </multiselect>
    </b-form-group>
    <div v-if="selectedRuleIds.length" class="mt-2">
      <small class="text-muted">Selected ({{ selectedRuleIds.length }}):</small>
      <div v-for="sel in selectedRuleIds" :key="sel.value" class="d-flex align-items-center mt-1">
        <b-badge variant="light" class="mr-1">{{ sel.text }}</b-badge>
        <b-icon
          icon="x-circle"
          class="text-danger clickable"
          font-scale="0.8"
          @click="selectedRuleIds = selectedRuleIds.filter((s) => s.value !== sel.value)"
        />
      </div>
    </div>
    <template #modal-footer="{ cancel, ok }">
      <b-button @click="cancel()">Cancel</b-button>
      <b-button variant="info" :disabled="selectedRuleIds.length === 0" @click="ok()">
        Add {{ selectedRuleIds.length }} {{ term.plural }}
      </b-button>
    </template>
  </b-modal>
</template>

<script>
import Multiselect from "vue-multiselect";
import "vue-multiselect/dist/vue-multiselect.min.css";
import { RULE_TERM, MESSAGE_LABELS, selectedCountLabel } from "../../constants/terminology";
import { truncateId } from "../../utils/idFormatter";

export default {
  name: "AlsoSatisfiesModal",
  components: { Multiselect },
  props: {
    rules: {
      type: Array,
      required: true,
    },
    selectedRule: {
      type: Object,
      default: null,
    },
    componentPrefix: {
      type: String,
      required: true,
    },
    showSRGIdChecked: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      selectedRuleIds: [],
      showRuleId: false,
      term: RULE_TERM,
      msg: MESSAGE_LABELS,
    };
  },
  computed: {
    filteredSelectRules() {
      const rule = this.selectedRule;
      if (!rule) return [];

      return this.rules
        .filter((r) => {
          return (
            r.id !== rule.id &&
            r.satisfies.length === 0 &&
            !rule.satisfies.some((s) => s.id === r.id)
          );
        })
        .map((r) => {
          const ruleLabel = `${this.componentPrefix}-${r.rule_id}`;
          const srgLabel = truncateId(r.srg_id) || ruleLabel;
          return {
            value: r.id,
            text: this.showRuleId ? `${ruleLabel} (${srgLabel})` : `${srgLabel} (${ruleLabel})`,
          };
        });
    },
  },
  methods: {
    selectedCountLabel,
    addMultipleSatisfiedRules() {
      const rule = this.selectedRule;
      if (!rule) return;
      this.selectedRuleIds.forEach((item) => {
        const ruleId = typeof item === "object" ? item.value : item;
        this.$emit("add-satisfied", ruleId, rule.id);
      });
    },
    clearSelectedRules() {
      this.selectedRuleIds = [];
    },
  },
};
</script>
