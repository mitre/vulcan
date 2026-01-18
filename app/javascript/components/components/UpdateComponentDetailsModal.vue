<script>
import axios from 'axios'
import SimpleTypeahead from 'vue3-simple-typeahead'
import AlertMixinVue from '../../mixins/AlertMixin.vue'
import FormMixinVue from '../../mixins/FormMixin.vue'
import 'vue3-simple-typeahead/dist/vue3-simple-typeahead.css'

export default {
  name: 'UpdateComponentDetailsModal',
  components: { SimpleTypeahead },
  mixins: [AlertMixinVue, FormMixinVue],
  props: {
    component: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      name: this.component.name,
      version: this.component.version,
      release: this.component.release,
      title: this.component.title,
      description: this.component.description,
      prefix: this.component.prefix,
      potentialPocs: this.component.all_users,
      admin_name: this.component.admin_name,
      admin_email: this.component.admin_email,
    }
  },
  methods: {
    resetModal() {
      this.name = this.component.name
      this.version = this.component.version
      this.release = this.component.release
      this.title = this.component.title
      this.description = this.component.description
      this.prefix = this.component.prefix
      this.potentialPocs = this.component.all_users
      this.admin_name = this.component.admin_name
      this.admin_email = this.component.admin_email
    },
    showModal() {
      this.$refs.updateComponentDetailsModal.show()
    },
    setComponentPoc(user) {
      this.admin_email = user.email
      this.admin_name = user.name
    },
    updateComponentDetails() {
      this.$refs.updateComponentDetailsModal.hide()
      const payload = { component: {} };
      [
        'name',
        'version',
        'release',
        'title',
        'description',
        'prefix',
        'admin_name',
        'admin_email',
      ].forEach((attr) => {
        if (payload.component[attr] !== this[attr]) {
          payload.component[attr] = this[attr]
        }
      })
      axios
        .put(`/components/${this.component.id}`, payload)
        .then(this.updateComponentDetailsSuccess)
        .catch(this.alertOrNotifyResponse)
    },
    updateComponentDetailsSuccess(response) {
      this.alertOrNotifyResponse(response)
      this.$emit('componentUpdated')
    },
  },
}
</script>

<template>
  <div>
    <b-button class="px-2 m-2" variant="success" @click="showModal()">
      Update Details
    </b-button>
    <b-modal
      ref="updateComponentDetailsModal"
      title="Update Details"
      size="lg"
      ok-title="Update Details"
      @show="resetModal()"
      @ok="updateComponentDetails()"
    >
      <b-form @submit="updateComponentDetails()">
        <!-- Name the component -->
        <b-form-group label="Name">
          <b-form-input v-model="name" placeholder="Component Name" required autocomplete="off" />
        </b-form-group>
        <!-- Version and Release -->
        <b-row>
          <b-col>
            <b-form-group label="Version">
              <b-form-input v-model="version" autocomplete="off" />
            </b-form-group>
          </b-col>
          <b-col>
            <b-form-group label="Release">
              <b-form-input v-model="release" autocomplete="off" />
            </b-form-group>
          </b-col>
        </b-row>
        <!-- STIG ID Prefix -->
        <b-form-group
          label="STIG ID Prefix"
          description="STIG IDs for each control will be automatically generated based on this prefix value"
        >
          <b-form-input
            v-model="prefix"
            placeholder="Example... ABCD-EF, ABCD-00"
            required
            autocomplete="off"
          />
        </b-form-group>

        <!-- Title -->
        <b-form-group label="Title">
          <b-form-input v-model="title" placeholder="Component Title" required autocomplete="off" />
        </b-form-group>
        <!-- Description -->
        <b-form-group label="Description">
          <b-form-textarea v-model="description" placeholder="" rows="3" />
        </b-form-group>
        <!-- Select PoC -->
        <b-form-group label="Select the Point of Contact">
          <SimpleTypeahead
            :key="`componentKey-${component.id}`"
            ref="userSearch"
            :default-item="admin_name"
            :items="potentialPocs"
            :item-projection="item => item.name"
            placeholder="Search for eligible PoC..."
            :min-input-length="0"
            @select-item="setComponentPoc"
          />
        </b-form-group>
        <!-- Allow the enter button to submit the form -->
        <b-button type="submit" class="d-none" @click.prevent="updateComponentDetails()" />
      </b-form>
    </b-modal>
  </div>
</template>

<style scoped></style>
