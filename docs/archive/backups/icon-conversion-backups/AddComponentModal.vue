<template>
  <div>
    <!-- Modal trigger button -->
    <b-button class="px-2 m-2" variant="primary" @click="showModal()">
      Import a Released Component
    </b-button>

    <!-- Add component modal -->
    <b-modal
      ref="AddComponentModal"
      title="Add Project Component"
      size="lg"
      ok-title="Add Component"
      @show="resetModal()"
      @ok="addComponent()"
    >
      <!-- Searchable projects -->
      <b-form v-if="!selectedComponent" @submit="addComponent()">
        <input
          id="AddComponentAuthenticityToken"
          type="hidden"
          name="authenticity_token"
          :value="authenticityToken"
        />
        <b-row>
          <b-col class="d-flex">
            <b-input-group>
              <b-input-group-prepend>
                <b-input-group-text>
                  <i class="mdi mdi-magnify" aria-hidden="true" />
                </b-input-group-text>
              </b-input-group-prepend>
              <vue-simple-suggest
                ref="componentSearch"
                v-model="search"
                :list="addDisplayNameToComponents(available_components)"
                :filter-by-query="true"
                value-attribute="id"
                display-attribute="displayed"
                placeholder="Search for a component by name..."
                :styles="projectSearchStyles"
                @select="setSelectedComponent($refs.componentSearch.selected)"
              />
            </b-input-group>

            <!-- Allow the enter button to submit the form -->
            <b-btn type="submit" class="d-none" @click.prevent="addComponent()" />
          </b-col>
        </b-row>
      </b-form>

      <!-- When  -->
      <template v-if="selectedComponent">
        <ComponentCard :actionable="false" :component="selectedComponent" />
        <span class="text-danger clickable float-right mr-3" @click="chooseAnotherProject"
          >Choose a different component</span
        >
      </template>
    </b-modal>
  </div>
</template>

<script>
import axios from "axios";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import DisplayedComponentMixin from "../../mixins/DisplayedComponentMixin.vue";
import ComponentCard from "../components/ComponentCard.vue";
import VueSimpleSuggest from "vue-simple-suggest";
import "vue-simple-suggest/dist/styles.css";

function initialState() {
  return {
    selectedComponent: null,
    search: "",
    projectSearchStyles: {
      vueSimpleSuggest: "flex1",
      inputWrapper: "",
      defaultInput: "",
      suggestions: "",
      suggestItem: "",
    },
  };
}

export default {
  name: "AddComponentModal",
  components: {
    VueSimpleSuggest,
    ComponentCard,
  },
  mixins: [AlertMixinVue, FormMixinVue, DisplayedComponentMixin],
  props: {
    project_id: {
      type: Number,
      required: true,
    },
    available_components: {
      type: Array,
      required: true,
    },
  },
  data: function () {
    return initialState();
  },
  methods: {
    resetModal: function () {
      Object.assign(this.$data, initialState());
    },
    showModal: function () {
      this.$refs["AddComponentModal"].show();
    },
    chooseAnotherProject: function () {
      this.search = "";
      this.selectedComponent = null;
    },
    setSelectedComponent: function (component) {
      this.selectedComponent = component;
    },
    addComponent: function () {
      // Guard if no component project selected
      if (!this.selectedComponent) {
        return;
      }

      this.$refs["AddComponentModal"].hide();
      let payload = {
        component: {
          component_id: this.selectedComponent.id,
        },
      };

      axios
        .post(`/projects/${this.project_id}/components`, payload)
        .then(this.addComponentSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    addComponentSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.$refs["AddComponentModal"].hide();
      this.$emit("projectUpdated");
    },
  },
};
</script>

<style scoped>
.flex1 {
  flex: 1;
}
</style>
