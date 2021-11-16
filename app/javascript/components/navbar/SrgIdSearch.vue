<template>
  <div>
    <b-input-group class="search-input">
      <b-input-group-prepend>
        <b-input-group-text class="form-control">
          <i class="mdi mdi-magnify" aria-hidden="true" />
        </b-input-group-text>
      </b-input-group-prepend>
      <b-form-input
        id="srg-id-search"
        v-model="searchText"
        debounce="250"
        placeholder="Search by SRG Version"
        @focus="focus = true"
        @blur="focus = false"
      />
    </b-input-group>
    <b-popover
      triggers="focus"
      target="srg-id-search"
      placement="bottom"
      custom-class="srg-id-search-results"
    >
      <!-- Render an empty div so that the popover detects the first focus (when there are not yet search results) -->
      <div />
      <b-card v-if="showProjects" no-body class="search-card overflow-auto shadow border-light">
        <b-card-header class="sticky-top bg-light">Projects</b-card-header>
        <b-list-group flush>
          <b-list-group-item
            v-for="project in projects"
            :key="project[0]"
            class="text-truncate"
            :href="`/projects/${project[0]}`"
            >{{ project[1] }}</b-list-group-item
          >
        </b-list-group>
      </b-card>
      <b-card v-if="showComponents" no-body class="search-card overflow-auto shadow border-light">
        <b-card-header class="sticky-top bg-light">Components</b-card-header>
        <b-list-group flush>
          <b-list-group-item
            v-for="comp in components"
            :key="comp[0]"
            class="text-truncate"
            :href="`/components/${comp[0]}`"
            >{{ comp[1] }}</b-list-group-item
          >
        </b-list-group>
      </b-card>
      <b-card v-if="showRules" no-body class="search-card overflow-auto shadow border-light">
        <b-card-header class="sticky-top bg-light">Rules</b-card-header>
        <b-list-group flush>
          <b-list-group-item
            v-for="rule in rules"
            :key="rule[0]"
            class="text-truncate"
            :href="`/components/${rule[2]}`"
            @click="selectRule(rule[2], rule[0])"
            >{{ `${rule[3]}-${rule[1]}` }}</b-list-group-item
          >
        </b-list-group>
      </b-card>
      <b-card
        v-if="!showRules && !showComponents && !showProjects"
        no-body
        class="search-card overflow-auto shadow border-light"
      >
        <b-card-header class="sticky-top bg-light">No Results</b-card-header>
      </b-card>
    </b-popover>
  </div>
</template>

<script>
import axios from "axios";
import SelectedRulesMixin from "../../mixins/SelectedRulesMixin";

export default {
  name: "SrgIdSearch",
  mixins: [SelectedRulesMixin],
  data() {
    return {
      focus: false,
      loading: false,
      searchText: "",
      component: {}, // This will be set when navigating to a rule
      projects: [],
      components: [],
      rules: [],
    };
  },
  computed: {
    show: function () {
      return (this.showProjects || this.showComponents || this.showRules) && this.focus;
    },
    showProjects: function () {
      return this.projects?.length > 0;
    },
    showComponents: function () {
      return this.components?.length > 0;
    },
    showRules: function () {
      return this.rules?.length > 0;
    },
  },
  watch: {
    searchText: async function (query) {
      const [projectResp, componentResp, ruleResp] = await Promise.all([
        axios.get("/search/projects", { params: { q: query } }),
        axios.get("/search/components", { params: { q: query } }),
        axios.get("/search/rules", { params: { q: query } }),
      ]);
      this.projects = projectResp.data.projects;
      this.components = componentResp.data.components;
      this.rules = ruleResp.data.rules;
    },
  },
  methods: {
    selectRule: function (componentId, ruleId) {
      this.component = { id: componentId }; // Needs to be set for SelectedRulesMixin
      this.handleRuleSelected(ruleId);
    },
  },
};
</script>

<style>
/* popover's custom-class doesn't allow these to be scoped */
.srg-id-search-results {
  min-width: 448px;
  margin-top: 0;
  border: none;
}

.srg-id-search-results > .arrow {
  display: none;
}

.srg-id-search-results > .popover-body {
  padding: 0;
}
</style>

<style scoped>
.search-card {
  max-height: 192px;
}

.search-input {
  min-width: 320px;
}
</style>
