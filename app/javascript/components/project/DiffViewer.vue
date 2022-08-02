<template>
  <div class="my-1">
    <b-row class="my-1">
      <b-col md="2">
        <div v-if="Object.keys(ruleDiffs).length === 0" class="p-2">
          <h6>Compare Components:</h6>
        </div>
        <div v-else id="sidebar-wrapper">
          <div id="scrolling-sidebar" ref="sidebar" :style="sidebarStyle">
            <!-- Filter -->
            <b-form-group label="Filter">
              <b-form-checkbox
                id="rcFilterChecked-filter"
                v-model="filters.rcFilterChecked"
                size="sm"
                class="mb-1 unselectable"
                name="rcFilterChecked-filter"
              >
                <strong>({{ ruleDiffFilterCounts.rc }})</strong> Rule Changed
              </b-form-checkbox>
            </b-form-group>
            <div
              v-for="rule_id in filteredRuleDiffIds"
              :key="`rule-${rule_id}`"
              :class="ruleRowClass(rule_id)"
              @click="ruleSelected(rule_id)"
            >
              {{ baseComponent.prefix }}-{{ rule_id }}
              <i
                v-if="ruleDiffs[rule_id].changed"
                class="mdi mdi-file-document-edit-outline float-right diff-icon"
                aria-hidden="true"
              />
            </div>
          </div>
        </div>
      </b-col>
      <b-col md="10">
        <b-input-group size="sm" class="mb-2">
          <b-input-group-prepend>
            <b-input-group-text class="rounded-0">Base</b-input-group-text>
          </b-input-group-prepend>
          <b-form-select
            id="diffComponent"
            v-model="diffComponent"
            class="form-select-sm"
            :disabled="!baseComponent"
            @change="compareComponents"
          >
            <option
              v-for="(selectOption, indexOpt) in compareList"
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
              {{ selectOption.project_name && `- ${selectOption.project_name}` }}
            </option>
          </b-form-select>
          <b-input-group-prepend>
            <b-input-group-text class="rounded-0">Compare</b-input-group-text>
          </b-input-group-prepend>
          <b-form-select
            id="baseComponent"
            v-model="baseComponent"
            class="form-select-sm"
            @change="updateCompareList"
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
          v-if="diffControl || baseControl"
          :key="selectedRuleId"
          :diff-editor="true"
          :original="diffControl"
          :value="baseControl"
          :options="monacoEditorOptions"
          :language="monacoEditorOptions.language"
          class="editor"
        />
      </b-col>
    </b-row>
  </div>
</template>

<script>
import _ from "lodash";
import axios from "axios";
import MonacoEditor from "vue-monaco";
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
      sidebarOffset: 0, // How far the sidebar is from the top of the screen
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
      filters: {
        rcFilterChecked: true, // Rule Changed
      },
      compareList: [],
      ruleDiffs: {},
      ruleDiffFilterCounts: {
        rc: 0,
      },
      filteredRuleDiffIds: [],
      selectedRuleId: null,
      baseControl: "",
      diffControl: "",
    };
  },
  computed: {
    sidebarStyle: function () {
      return {
        "max-height": `calc(100vh - ${this.sidebarOffset}px)`,
      };
    },
  },
  watch: {
    ruleDiffs: function () {
      this.ruleDiffFilterCounts = this.calculateRuleDiffFilterCounts();
      this.filteredRuleDiffIds = this.filterRuleDiffIds();
    },
    filters: {
      handler() {
        this.filteredRuleDiffIds = this.filterRuleDiffIds();
        localStorage.setItem(`diffViewerFilters-${this.componentId}`, JSON.stringify(this.filters));
      },
      deep: true,
    },
  },
  mounted: function () {
    // Persist `filters` across page loads
    if (localStorage.getItem(`diffViewerFilters-${this.componentId}`)) {
      try {
        this.filters = JSON.parse(localStorage.getItem(`diffViewerFilters-${this.componentId}`));
      } catch (e) {
        localStorage.removeItem(`diffViewerFilters-${this.componentId}`);
      }
    }
    window.addEventListener("scroll", this.handleScroll);
    this.handleScroll();
    // Load saved theme
    const savedTheme = localStorage.getItem("monacoEditorTheme");
    if (savedTheme) {
      this.monacoEditorOptions.theme = savedTheme;
      this.editorKey += 1;
    }
  },
  destroyed() {
    window.removeEventListener("scroll", this.handleScroll);
  },
  methods: {
    calculateRuleDiffFilterCounts: function () {
      return {
        rc: Object.values(this.ruleDiffs).filter((ruleDiff) => ruleDiff.changed).length,
      };
    },
    filterRuleDiffIds: function (ruleDiffs) {
      return Object.entries(this.ruleDiffs)
        .filter(([_, ruleDiff]) => {
          return this.filters.rcFilterChecked ? ruleDiff.changed : true;
        })
        .map(([ruleId, _]) => {
          return ruleId;
        });
    },
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
      const control = this.ruleDiffs[rule_id];
      this.baseControl = control["base"];
      this.diffControl = control["diff"];
    },
    ruleDeselected: function () {
      this.selectedRuleId = null;
      this.baseControl = "";
      this.diffControl = "";
    },
    updateCompareList: function () {
      this.ruleDeselected();
      if (this.baseComponent) {
        axios
          .get(`/components/${this.baseComponent.id}/based_on_same_srg`)
          .then((response) => {
            this.compareList = response.data;
          })
          .catch(this.alertOrNotifyResponse);
      }
    },
    compareComponents: function () {
      this.ruleDeselected();
      if (
        this.baseComponent &&
        this.diffComponent &&
        this.baseComponent.id !== this.diffComponent.id
      ) {
        axios
          .get(`/components/${this.baseComponent.id}/compare/${this.diffComponent.id}`)
          .then((response) => {
            this.ruleDiffs = response.data;
          })
          .catch(this.alertOrNotifyResponse);
      }
    },
    updateSettings: function (setting, value) {
      this.monacoEditorOptions[setting] = value;
      this.editorKey += 1;
    },
    handleScroll: function () {
      this.$nextTick(() => {
        // Get the distance from the top of the sidebar to the top of the page
        let top = this.$refs.sidebar?.getBoundingClientRect().top;
        // if top is set and greater than 0 then set the sidebar offset to keep
        // the scrollbar from going off the page
        this.sidebarOffset = top > 0 ? top : 0;
      });
    },
  },
};
</script>

<style scoped>
#scrolling-sidebar {
  display: block;
  overflow-y: auto;
}

.form-select-sm {
  height: 2rem;
}

.ruleRow {
  padding: 0.25em;
}

.ruleRow:hover {
  background: rgb(0, 0, 0, 0.12);
}

.selectedRuleRow {
  background: rgba(66, 50, 50, 0.09);
}

.diff-icon {
  color: red;
}

.editor {
  width: auto;
  height: 1000px;
}
</style>

<style>
.suggest-widget {
  border: none !important;
}
</style>
