<template>
  <div>
    <h1>Released Components</h1>

    <p>
      <b>Component Count:</b> <span>{{ components.length }}</span>
    </p>

    <!-- Component search -->
    <div class="row">
      <div class="col-6">
        <div class="input-group">
          <div class="input-group-prepend">
            <div class="input-group-text">
              <i class="mdi mdi-magnify" aria-hidden="true" />
            </div>
          </div>
          <input
            id="componentSearch"
            v-model="search"
            type="text"
            class="form-control"
            placeholder="Search components..."
          />
        </div>
      </div>
    </div>

    <br />

    <b-row cols="1" cols-sm="1" cols-md="1" cols-lg="2">
      <b-col v-for="component in sortedFilteredComponents()" :key="component.id">
        <ComponentCard :component="component" :actionable="false" />
      </b-col>
    </b-row>
  </div>
</template>

<script>
import ComponentCard from "./ComponentCard.vue";

export default {
  name: "Projectcomponent",
  components: {
    ComponentCard,
  },
  props: {
    components: {
      type: Array,
      required: true,
    },
  },
  data: function () {
    return {
      search: "",
    };
  },
  methods: {
    sortedFilteredComponents() {
      let downcaseSearch = this.search.toLowerCase();
      let filteredComponents = this.components.filter((component) =>
        component.name.toLowerCase().includes(downcaseSearch)
      );

      return filteredComponents.sort((c_1, c_2) => {
        return c_1.name.toLowerCase().localeCompare(c_2.name.toLowerCase());
      });
    },
  },
};
</script>

<style scoped></style>
