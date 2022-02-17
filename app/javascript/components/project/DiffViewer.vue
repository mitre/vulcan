<template>
  <div class="my-1">
    <b-row class="my-1">
      <b-col md="2">
        <div class="p-2">
          <h5>Compare Components:</h5>
        </div>
      </b-col>
      <b-col md="5">
        <b-form-select v-model="baseComponent" class="rounded-0" @change="compareComponents">
          <option
            v-for="(selectOption, indexOpt) in project.components"
            :key="indexOpt"
            :value="selectOption"
          >
            {{ selectOption.name }}
          </option>
        </b-form-select>
      </b-col>
      <b-col md="5">
        <b-form-select v-model="diffComponent" class="rounded-0" @change="compareComponents">
          <option
            v-for="(selectOption, indexOpt) in project.components"
            :key="indexOpt"
            :value="selectOption"
          >
            {{ selectOption.name }}
          </option>
        </b-form-select>
      </b-col>
    </b-row>
    <b-row class="my-1">
      <b-col md="2">
        <div
          v-for="rule_id in Object.keys(diffRules)"
          :key="`rule-${rule_id}`"
          :class="ruleRowClass(rule_id)"
          @click="ruleSelected(rule_id)"
        >
          {{ baseComponent.prefix }}-{{ rule_id }}
        </div>
      </b-col>
      <b-col md="10">
        <MonacoEditor
          :key="selectedRuleId"
          :diff-editor="true"
          :original="baseControl"
          :value="diffControl"
          :options="monacoEditorOptions"
          width="auto"
          height="1000"
        />
      </b-col>
    </b-row>
  </div>
</template>

<script>
import _ from "lodash";
import axios from "axios";
import MonacoEditor from "monaco-editor-vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "DiffViewer",
  components: {
    MonacoEditor,
  },
  mixins: [AlertMixinVue],
  props: {
    project: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return {
      monacoEditorOptions: {
        automaticLayout: true,
        language: "ruby",
        readOnly: true,
        "semanticHighlighting.enabled": true,
        tabSize: 2,
        theme: "vs-dark",
      },
      baseComponent: null,
      diffComponent: null,
      diffRules: [],
      selectedRuleId: null,
      baseControl: "",
      diffControl: "",
    };
  },
  methods: {
    // Dynamically set the class of each rule row
    ruleRowClass: function (rule_id) {
      return {
        ruleRow: true,
        clickable: true,
        selectedRuleRow: this.selectedRuleId == rule_id,
      };
    },
    ruleSelected: function (rule_id) {
      this.selectedRuleId = rule_id;
      const control = this.diffRules[rule_id];
      this.baseControl = control["base"];
      this.diffControl = control["diff"];
    },
    compareComponents: function () {
      if (
        this.baseComponent &&
        this.diffComponent &&
        this.baseComponent.id !== this.diffComponent.id
      ) {
        axios
          .get(`/components/${this.baseComponent.id}/compare/${this.diffComponent.id}`)
          .then((response) => {
            this.diffRules = response.data;
          })
          .catch(this.alertOrNotifyResponse);
      }
    },
  },
};
</script>

<style scoped>
.ruleRow {
  padding: 0.25em;
}

.selectedRuleRow {
  background: rgba(66, 50, 50, 0.09);
}
</style>
