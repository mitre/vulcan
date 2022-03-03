<template>
  <div class="my-1">
    <b-row class="my-1">
      <b-col md="2">
        <div
          v-for="rule_id in Object.keys(diffRules)"
          :key="`rule-${rule_id}`"
          :class="ruleRowClass(rule_id)"
          @click="ruleSelected(rule_id)"
        >
          {{ baseComponent.prefix }}-{{ rule_id }}
          <i
            v-if="diffRules[rule_id].changed"
            class="mdi mdi-file-document-edit-outline float-right diff-icon"
            aria-hidden="true"
          />
        </div>
      </b-col>
      <b-col md="10">
        <b-input-group size="sm" class="mb-2">
          <b-input-group-prepend>
            <b-input-group-text class="rounded-0">Base</b-input-group-text>
          </b-input-group-prepend>
          <b-form-select
            id="baseComponent"
            v-model="baseComponent"
            class="form-select-sm"
            @change="compareComponents"
          >
            <option
              v-for="(selectOption, indexOpt) in project.components"
              :key="indexOpt"
              :value="selectOption"
            >
              {{ selectOption.name }}
              {{
                selectOption.version || selectOption.release
                  ? `(${[
                      selectOption.version ? `Version ${selectOption.version}` : "",
                      selectOption.release ? `Release ${selectOption.release}` : "",
                    ].join(", ")})`
                  : ""
              }}
            </option>
          </b-form-select>
          <b-input-group-prepend>
            <b-input-group-text class="rounded-0">Compare</b-input-group-text>
          </b-input-group-prepend>
          <b-form-select
            id="diffComponent"
            v-model="diffComponent"
            class="form-select-sm"
            @change="compareComponents"
          >
            <option
              v-for="(selectOption, indexOpt) in project.components"
              :key="indexOpt"
              :value="selectOption"
            >
              {{ selectOption.name }}
              {{
                selectOption.version || selectOption.release
                  ? `(${[
                      selectOption.version ? `Version ${selectOption.version}` : "",
                      selectOption.release ? `Release ${selectOption.release}` : "",
                    ].join(", ")})`
                  : ""
              }}
            </option>
          </b-form-select>
          <b-button
            size="sm"
            squared
            @click="updateSettings('renderSideBySide', !monacoEditorOptions.renderSideBySide)"
          >
            {{ monacoEditorOptions.renderSideBySide ? "Inline View" : "Side-By-Side View" }}
          </b-button>
        </b-input-group>
        <MonacoEditor
          v-if="Object.keys(diffRules).length > 0"
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
      editorKey: 0,
      monacoEditorOptions: {
        automaticLayout: true,
        language: "ruby",
        readOnly: true,
        renderSideBySide: true,
        tabSize: 2,
        theme: "vs-dark",
      },
      baseComponent: null,
      diffComponent: null,
      diffRules: {},
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
    updateSettings: function (setting, value) {
      this.monacoEditorOptions[setting] = value;
      this.editorKey += 1;
    },
  },
};
</script>

<style scoped>
.form-select-sm {
  height: 2rem;
}

.ruleRow {
  padding: 0.25em;
}

.selectedRuleRow {
  background: rgba(66, 50, 50, 0.09);
}

.diff-icon {
  color: red;
}
</style>
