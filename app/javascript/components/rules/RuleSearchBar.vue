<template>
  <div>
    <FindAndReplace
      :component-id="componentId"
      :project-prefix="projectPrefix"
      :rules="rules"
      :read-only="readOnly"
      class="mb-2"
    />

    <p class="mb-2">
      <strong>Filter</strong>
      <span
        data-test="clear-filters"
        class="text-primary clickable float-right"
        @click="$emit('clear-filters')"
      >
        clear
      </span>
      <span
        v-b-tooltip.hover
        title="Search requirements (Cmd+K)"
        class="text-primary clickable float-right mr-2"
        @click="$bvModal.show('component-search-modal')"
      >
        <b-icon icon="search" />
      </span>
    </p>
    <div class="input-group">
      <input
        id="ruleSearch"
        ref="ruleSearch"
        type="text"
        class="form-control"
        placeholder="Filter by ID..."
        :value="searchValue"
        @input="onSearchInput($event.target.value)"
      />
    </div>

    <ComponentSearchModal
      :component-id="componentId"
      :project-prefix="projectPrefix"
      search-type="rules"
      @selected="$emit('search-result-selected', $event)"
    />
  </div>
</template>

<script>
import _ from "lodash";
import FindAndReplace from "./FindAndReplace.vue";
import ComponentSearchModal from "../shared/ComponentSearchModal.vue";

export default {
  name: "RuleSearchBar",
  components: { FindAndReplace, ComponentSearchModal },
  props: {
    componentId: {
      type: Number,
      required: true,
    },
    projectPrefix: {
      type: String,
      required: true,
    },
    rules: {
      type: Array,
      required: true,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
    searchValue: {
      type: String,
      default: "",
    },
  },
  methods: {
    onSearchInput: _.debounce(function (value) {
      this.$emit("search-updated", value);
    }, 500),
    setSearchValue(value) {
      if (this.$refs.ruleSearch) {
        this.$refs.ruleSearch.value = value;
      }
    },
  },
};
</script>
