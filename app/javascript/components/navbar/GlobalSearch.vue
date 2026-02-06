<template>
  <div>
    <b-input-group class="search-input">
      <b-input-group-prepend>
        <b-input-group-text class="form-control">
          <b-icon icon="search" aria-hidden="true" />
        </b-input-group-text>
      </b-input-group-prepend>
      <b-form-input
        id="srg-id-search"
        v-model="searchText"
        debounce="300"
        placeholder="Search projects, components, rules, SRGs, STIGs..."
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
            :href="`/components/${rule[2]}?stig_id=${rule[1]}`"
            >{{ `${rule[3]}-${rule[1]}` }}</b-list-group-item
          >
        </b-list-group>
      </b-card>
      <b-card v-if="showSrgs" no-body class="search-card overflow-auto shadow border-light">
        <b-card-header class="sticky-top bg-light">SRGs</b-card-header>
        <b-list-group flush>
          <b-list-group-item
            v-for="srg in srgs"
            :key="srg[0]"
            class="text-truncate"
            :href="`/srgs/${srg[0]}`"
            >{{ srg[1] }}</b-list-group-item
          >
        </b-list-group>
      </b-card>
      <b-card v-if="showStigs" no-body class="search-card overflow-auto shadow border-light">
        <b-card-header class="sticky-top bg-light">STIGs</b-card-header>
        <b-list-group flush>
          <b-list-group-item
            v-for="stig in stigs"
            :key="stig[0]"
            class="text-truncate"
            :href="`/stigs/${stig[0]}`"
            >{{ stig[1] }}</b-list-group-item
          >
        </b-list-group>
      </b-card>
      <b-card v-if="showStigRules" no-body class="search-card overflow-auto shadow border-light">
        <b-card-header class="sticky-top bg-light">STIG Rules</b-card-header>
        <b-list-group flush>
          <b-list-group-item
            v-for="rule in stigRules"
            :key="rule.id"
            class="text-truncate"
            :href="`/stigs/${rule.stig_id}?rule_id=${rule.rule_id}`"
          >
            <span class="font-weight-bold">{{ rule.rule_id }}</span>
            <small class="text-muted ml-1">{{ rule.title }}</small>
          </b-list-group-item>
        </b-list-group>
      </b-card>
      <b-card v-if="showSrgRules" no-body class="search-card overflow-auto shadow border-light">
        <b-card-header class="sticky-top bg-light">SRG Rules</b-card-header>
        <b-list-group flush>
          <b-list-group-item
            v-for="rule in srgRules"
            :key="rule.id"
            class="text-truncate"
            :href="`/srgs/${rule.srg_id}?rule_id=${rule.rule_id}`"
          >
            <span class="font-weight-bold">{{ rule.rule_id }}</span>
            <small class="text-muted ml-1">{{ rule.title }}</small>
          </b-list-group-item>
        </b-list-group>
      </b-card>
      <b-card
        v-if="
          !showRules &&
          !showComponents &&
          !showProjects &&
          !showSrgs &&
          !showStigs &&
          !showStigRules &&
          !showSrgRules
        "
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

export default {
  name: "GlobalSearch",
  data() {
    return {
      focus: false,
      loading: false,
      searchText: "",
      projects: [],
      components: [],
      rules: [],
      srgs: [],
      stigs: [],
      stigRules: [],
      srgRules: [],
    };
  },
  computed: {
    show: function () {
      return (
        (this.showProjects ||
          this.showComponents ||
          this.showRules ||
          this.showSrgs ||
          this.showStigs ||
          this.showStigRules ||
          this.showSrgRules) &&
        this.focus
      );
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
    showSrgs: function () {
      return this.srgs?.length > 0;
    },
    showStigs: function () {
      return this.stigs?.length > 0;
    },
    showStigRules: function () {
      return this.stigRules?.length > 0;
    },
    showSrgRules: function () {
      return this.srgRules?.length > 0;
    },
  },
  watch: {
    searchText: async function (query) {
      // Only search for 2+ character queries
      if (!query || query.trim().length < 2) {
        this.projects = [];
        this.components = [];
        this.rules = [];
        this.srgs = [];
        this.stigs = [];
        this.stigRules = [];
        this.srgRules = [];
        return;
      }

      this.loading = true;
      try {
        // Use new unified search API
        const response = await axios.get("/api/search/global", {
          params: { q: query, limit: 10 },
        });

        // Transform API response to match expected format
        // projects: [[id, name], ...]
        this.projects = (response.data.projects || []).map((p) => [p.id, p.name]);
        // components: [[id, name], ...]
        this.components = (response.data.components || []).map((c) => [c.id, c.name]);
        // rules: [[id, rule_id, component_id, component_prefix], ...]
        this.rules = (response.data.rules || []).map((r) => [
          r.id,
          r.rule_id,
          r.component_id,
          r.component_prefix || "",
        ]);
        // srgs: [[id, name], ...]
        this.srgs = (response.data.srgs || []).map((s) => [s.id, s.name]);
        // stigs: [[id, name], ...]
        this.stigs = (response.data.stigs || []).map((s) => [s.id, s.name]);
        // stig_rules: keep full objects for rule_id display
        this.stigRules = response.data.stig_rules || [];
        // srg_rules: keep full objects for rule_id display
        this.srgRules = response.data.srg_rules || [];
      } catch (error) {
        console.error("Search failed:", error);
        this.projects = [];
        this.components = [];
        this.rules = [];
        this.srgs = [];
        this.stigs = [];
        this.stigRules = [];
        this.srgRules = [];
      } finally {
        this.loading = false;
      }
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
