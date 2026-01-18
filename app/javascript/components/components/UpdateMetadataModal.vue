<script>
import axios from 'axios'
import AlertMixinVue from '../../mixins/AlertMixin.vue'
import FormMixinVue from '../../mixins/FormMixin.vue'

function initialState(component) {
  return {
    metadata: Object.entries(component.metadata || {}).map(([key, value]) => {
      return { key, value }
    }),
  }
}

export default {
  name: 'UpdateMetadataModal',
  mixins: [AlertMixinVue, FormMixinVue],
  props: {
    component: {
      type: Object,
      required: true,
    },
  },
  data() {
    return initialState(this.component)
  },
  methods: {
    resetModal() {
      Object.assign(this.$data, initialState(this.component))
    },
    showModal() {
      this.$refs.updateMetadataModal.show()
    },
    addMetadata() {
      this.metadata.push({ key: '', value: '' })
    },
    updateMetadata() {
      this.$refs.updateMetadataModal.hide()
      const payload = {
        component: {
          component_metadata_attributes: {
            data: this.metadata.reduce((acc, curr) => {
              acc[curr.key] = curr.value
              return acc
            }, {}),
          },
        },
      }

      axios
        .put(`/components/${this.component.id}`, payload)
        .then(this.updateMetadataSuccess)
        .catch(this.alertOrNotifyResponse)
    },
    updateMetadataSuccess(response) {
      this.alertOrNotifyResponse(response)
      this.$emit('componentUpdated')
    },
    removeMetadata(index) {
      this.metadata.splice(index, 1)
    },
  },
}
</script>

<template>
  <div>
    <b-button class="px-2 m-2" variant="success" @click="showModal()">
      Update Metadata
    </b-button>
    <b-modal
      ref="updateMetadataModal"
      title="Update Component Metadata"
      size="lg"
      ok-title="Update"
      @show="resetModal()"
      @ok="updateMetadata()"
    >
      <b-form @submit="updateMetadata()">
        <div v-for="(data, index) in metadata" :key="index" class="pb-2">
          <b-input-group>
            <b-form-input v-model="data.key" placeholder="Key" required />
            <b-form-input v-model="data.value" placeholder="Value" required />
            <!-- Add button for removing metadata entry -->
            <b-button variant="danger" size="sm" class="ml-2" @click="removeMetadata(index)">
              X
            </b-button>
          </b-input-group>
        </div>
        <b-row>
          <b-col>
            <b-button @click="addMetadata">
              Add
            </b-button>
          </b-col>
        </b-row>
        <!-- Allow the enter button to submit the form -->
        <b-button type="submit" class="d-none" @click.prevent="updateMetadata()" />
      </b-form>
    </b-modal>
  </div>
</template>

<style scoped></style>
