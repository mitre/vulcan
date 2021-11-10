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
      <b-card no-body class="search-card overflow-auto shadow border-light">
        <b-card-header class="sticky-top bg-light">Rules</b-card-header>
        <b-list-group flush>
          <b-list-group-item
            v-for="rule in rules"
            :key="rule[0]"
            class="text-truncate"
            href="/components"
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
      rules: [],
    };
  },
  computed: {
    show: function () {
      return this.rules?.length > 0 && this.focus;
    },
  },
  watch: {
    searchText: async function (text) {
      const resp = await axios.get("/search", { params: { text } });
      this.rules = resp.data.rules;
    },
  },
};
</script>

<style>
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
