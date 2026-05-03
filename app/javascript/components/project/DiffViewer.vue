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
              <b-icon
                v-if="ruleDiffs[rule_id].changed"
                icon="file-earmark-text"
                aria-hidden="true"
              />
            </div>
          </div>
        </div>
      </b-col>
      <b-col md="10">
        <b-input-group size="sm" class="mb-2">
          <b-input-group-prepend>
            <b-input-group-text class="rounded-0">Base (older)</b-input-group-text>
          </b-input-group-prepend>
          <FilterDropdown
            id="baseComponent"
            v-model="baseComponentId"
            :options="componentOptions"
            aria-label="Base component for diff"
            @input="updateCompareList"
          />
          <b-input-group-prepend>
            <b-input-group-text class="rounded-0">Compare (newer)</b-input-group-text>
          </b-input-group-prepend>
          <FilterDropdown
            id="diffComponent"
            v-model="diffComponentId"
            :options="compareListOptions"
            aria-label="Compare component for diff"
            @input="compareComponents"
          />
          <b-input-group-prepend>
            <b-input-group-text class="rounded-0">Theme</b-input-group-text>
          </b-input-group-prepend>
          <FilterDropdown
            id="diffTheme"
            :value="monacoEditorOptions.theme"
            :options="themeOptions"
            aria-label="Diff editor theme"
            @input="updateTheme"
          />
          <b-button
            size="sm"
            @click="updateSettings('renderSideBySide', !monacoEditorOptions.renderSideBySide)"
          >
            {{ monacoEditorOptions.renderSideBySide ? "Inline View" : "Side-By-Side View" }}
          </b-button>
        </b-input-group>
        <MonacoEditor
          v-if="diffControl || baseControl"
          :key="`${selectedRuleId}-${editorKey}`"
          :diff-editor="true"
          :original="diffControl"
          :value="baseControl"
          :options="monacoEditorOptions"
          :language="monacoEditorOptions.language"
          :theme="monacoEditorOptions.theme"
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
import FilterDropdown from "../shared/FilterDropdown.vue";

export default {
  name: "DiffViewer",
  components: {
    MonacoEditor,
    FilterDropdown,
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
      baseComponentId: null,
      diffComponentId: null,
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
    baseComponent() {
      if (this.baseComponentId == null) return null;
      return this.project.components.find((c) => c.id === this.baseComponentId) || null;
    },
    diffComponent() {
      if (this.diffComponentId == null) return null;
      return this.compareList.find((c) => c.id === this.diffComponentId) || null;
    },
    componentOptions() {
      return this.project.components.map((c) => ({
        value: c.id,
        text: this.componentDisplayLabel(c),
      }));
    },
    compareListOptions() {
      return this.compareList.map((c) => ({
        value: c.id,
        text: c.project_name
          ? `${this.componentDisplayLabel(c)} - ${c.project_name}`
          : this.componentDisplayLabel(c),
      }));
    },
    themeOptions() {
      return [
        { value: "vs", text: "Visual Studio" },
        { value: "vs-dark", text: "Visual Studio Dark" },
        { value: "hc-black", text: "High Contrast Dark" },
      ];
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
          .get(`/components/${this.baseComponent.id}/search/based_on_same_srg`)
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
    updateTheme: function (value) {
      this.monacoEditorOptions.theme = value;
      localStorage.setItem("monacoEditorTheme", value);
      this.editorKey += 1;
    },
    componentDisplayLabel(c) {
      const versionParts = [];
      if (c.version) versionParts.push(`Version ${c.version}`);
      if (c.release) versionParts.push(`Release ${c.release}`);
      const suffix = versionParts.length ? ` (${versionParts.join(", ")})` : "";
      return `${c.name}${suffix}`;
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
