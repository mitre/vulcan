<template>
  <div>
    <b-input-group>
      <b-input-group-prepend>
        <b-input-group-text class="form-control">
          <i class="mdi mdi-magnify" aria-hidden="true" />
        </b-input-group-text>
      </b-input-group-prepend>
      <b-form-input
        id="srg-id-search"
        v-model="searchText"
        debounce="500"
        placeholder="Search by SRG ID"
        @focus="focus = true"
        @blur="focus = false"
      />
    </b-input-group>
    <b-popover
      disabled
      :show="show"
      target="srg-id-search"
      placement="bottom"
      custom-class="srg-id-search-results"
    >
      <b-card
        v-if="projects && projects.length > 0"
        no-body
        class="search-card overflow-auto shadow border-light"
      >
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
      <b-card
        v-if="components && components.length > 0"
        no-body
        class="search-card overflow-auto shadow border-light"
      >
        <b-card-header class="sticky-top bg-light">Components</b-card-header>
        <b-list-group flush>
          <b-list-group-item
            v-for="component in components"
            :key="component[0]"
            class="text-truncate"
            :href="`/components/${component[0]}`"
            >{{ component[1] }}</b-list-group-item
          >
        </b-list-group>
      </b-card>
      <b-card
        v-if="rules && rules.length > 0"
        no-body
        class="search-card overflow-auto shadow border-light"
      >
        <b-card-header class="sticky-top bg-light">Rules</b-card-header>
        <b-list-group flush>
          <b-list-group-item
            v-for="rule in rules"
            :key="rule[0]"
            class="text-truncate"
            :href="`/components/${rule[2]}`"
            >{{ rule[1] }}</b-list-group-item
          >
        </b-list-group>
      </b-card>
    </b-popover>
  </div>
</template>

<script>
import axios from "axios";

export default {
  name: "SrgIdSearch",
  data() {
    return {
      focus: false,
      loading: false,
      searchText: "",
      projects: [],
      components: [],
      rules: [],
    };
  },
  computed: {
    show: function () {
      return (
        (this.projects?.length > 0 || this.components?.projects > 0 || this.rules?.length > 0) &&
        this.focus
      );
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
};
</script>

<style>
/* popover's custom-class doesn't allow these to be scoped */
.srg-id-search-results {
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
  max-height: 256px;
}
</style>
