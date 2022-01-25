<template>
  <span>
    <!-- Modal trigger button -->
    <span @click="showModal()">
      <slot name="opener">
        <b-button class="px-2 m-2" variant="primary"> Lock Component Controls </b-button>
      </slot>
    </span>

    <!-- Add component modal -->
    <b-modal
      ref="LockControlsModal"
      title="Lock Component Controls"
      size="lg"
      :ok-title="loading ? 'Loading...' : 'Lock Controls'"
      :ok-disabled="loading"
      @ok="lockControls"
    >
      <!-- Searchable projects -->
      <b-form @submit="lockControls()">
        <input
          id="NewProjectAuthenticityToken"
          type="hidden"
          name="authenticity_token"
          :value="authenticityToken"
        />
        <b-row>
          <b-col>
            <!-- Set the comment -->
            <b-form-group label="Comment">
              <b-form-textarea
                v-model="comment"
                placeholder="Leave a comment..."
                rows="3"
                required
              />
            </b-form-group>
          </b-col>
        </b-row>
      </b-form>
    </b-modal>
  </span>
</template>

<script>
import axios from "axios";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "LockControlsModal",
  mixins: [AlertMixinVue, FormMixinVue],
  props: {
    component_id: {
      type: Number,
      required: true,
    },
  },
  data: function () {
    return {
      comment: "",
      loading: false,
    };
  },
  methods: {
    showModal: function () {
      this.comment = "";
      this.$refs["LockControlsModal"].show();
    },
    lockControls: function (bvModalEvt) {
      this.loading = true;
      let failed = false;
      bvModalEvt.preventDefault();

      // Guard before POST
      if (!this.comment) {
        this.$bvToast.toast("Please enter a comment", {
          title: "Error",
          variant: "danger",
          solid: true,
        });
        failed = true;
      }
      if (failed) {
        this.loading = false;
        return;
      }

      axios
        .post(`/components/${this.component_id}/lock`, {
          review: { action: "lock_control", comment: this.comment },
        })
        .then(this.lockControlsSuccess)
        .catch(this.alertOrNotifyResponse)
        .finally(this.completeLoading);
    },
    completeLoading: function () {
      this.loading = false;
    },
    lockControlsSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.$refs["LockControlsModal"].hide();
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
