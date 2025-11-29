<script>
import axios from 'axios'
import SimpleTypeahead from 'vue3-simple-typeahead'
import 'vue3-simple-typeahead/dist/vue3-simple-typeahead.css'
import AlertMixinVue from '../../mixins/AlertMixin.vue'
import DisplayedComponentMixin from '../../mixins/DisplayedComponentMixin.vue'
import FormMixinVue from '../../mixins/FormMixin.vue'
import ComponentCard from '../components/ComponentCard.vue'

function initialState() {
  return {
    selectedComponent: null,
  }
}

export default {
  name: 'AddComponentModal',
  components: {
    SimpleTypeahead,
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
  data() {
    return initialState()
  },
  computed: {
    // Add display name to components for typeahead
    componentsWithDisplay() {
      return this.addDisplayNameToComponents(this.available_components)
    },
  },
  methods: {
    resetModal() {
      Object.assign(this.$data, initialState())
      // Clear the typeahead input
      if (this.$refs.componentSearch) {
        this.$refs.componentSearch.clearInput()
      }
    },
    showModal() {
      this.$refs.AddComponentModal.show()
    },
    chooseAnotherProject() {
      this.selectedComponent = null
      if (this.$refs.componentSearch) {
        this.$refs.componentSearch.clearInput()
      }
    },
    setSelectedComponent(component) {
      this.selectedComponent = component
    },
    // Projection function for typeahead display
    componentProjection(component) {
      return component.displayed || component.name || ''
    },
    addComponent() {
      // Guard if no component project selected
      if (!this.selectedComponent) {
        return
      }

      this.$refs.AddComponentModal.hide()
      const payload = {
        component: {
          component_id: this.selectedComponent.id,
        },
      }

      axios
        .post(`/projects/${this.project_id}/components`, payload)
        .then(this.addComponentSuccess)
        .catch(this.alertOrNotifyResponse)
    },
    addComponentSuccess(response) {
      this.alertOrNotifyResponse(response)
      this.$refs.AddComponentModal.hide()
      this.$emit('projectUpdated')
    },
  },
}
</script>

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
      <b-form v-if="!selectedComponent" @submit.prevent="addComponent()">
        <input
          id="AddComponentAuthenticityToken"
          type="hidden"
          name="authenticity_token"
          :value="authenticityToken"
        >
        <b-row>
          <b-col class="d-flex">
            <b-input-group>
              <b-input-group-text>
                <i class="bi bi-search" aria-hidden="true" />
              </b-input-group-text>
              <SimpleTypeahead
                id="componentSearch"
                ref="componentSearch"
                class="flex-grow-1"
                placeholder="Search for a component by name..."
                :items="componentsWithDisplay"
                :min-input-length="1"
                :item-projection="componentProjection"
                @select-item="setSelectedComponent"
              />
            </b-input-group>

            <!-- Allow the enter button to submit the form -->
            <b-button type="submit" class="d-none" @click.prevent="addComponent()" />
          </b-col>
        </b-row>
      </b-form>

      <!-- When component is selected -->
      <template v-if="selectedComponent">
        <ComponentCard :actionable="false" :component="selectedComponent" />
        <span class="text-danger clickable float-end me-3" @click="chooseAnotherProject">Choose a different component</span>
      </template>
    </b-modal>
  </div>
</template>

<style scoped>
.flex-grow-1 {
  flex-grow: 1;
}
</style>
