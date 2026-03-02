<template>
  <span>
    <!-- Modal trigger button -->
    <span @click="showModal()">
      <slot name="opener">
        <b-button class="px-2 m-2" variant="primary">{{ msg.lockAllTitle }}</b-button>
      </slot>
    </span>

    <!-- Lock rules modal -->
    <b-modal
      ref="LockControlsModal"
      :title="msg.lockAllTitle"
      size="lg"
      :ok-title="loading ? 'Loading...' : okButtonText"
      :ok-disabled="loading || (lockMode === 'sections' && selectedSections.length === 0)"
      @ok="handleOk"
    >
      <b-form @submit.prevent="handleOk">
        <input
          id="NewProjectAuthenticityToken"
          type="hidden"
          name="authenticity_token"
          :value="authenticityToken"
        />

        <!-- Lock Mode Selection -->
        <b-form-group label="Lock Mode" class="mb-3">
          <b-form-radio-group v-model="lockMode" stacked>
            <b-form-radio value="full" data-testid="lock-mode-full">
              <strong>Lock entire rules</strong>
              <br />
              <small class="text-muted">
                Locks all fields on all unlocked rules (existing behavior)
              </small>
            </b-form-radio>
            <b-form-radio value="sections" data-testid="lock-mode-sections">
              <strong>Lock sections only</strong>
              <br />
              <small class="text-muted">
                Lock specific sections across all rules while leaving other sections editable
              </small>
            </b-form-radio>
          </b-form-radio-group>
        </b-form-group>

        <!-- Section Selection (only visible in sections mode) -->
        <b-form-group
          v-if="lockMode === 'sections'"
          label="Sections to lock"
          data-testid="section-checkboxes"
        >
          <b-form-checkbox-group v-model="selectedSections" stacked>
            <b-form-checkbox v-for="section in sectionOptions" :key="section" :value="section">
              {{ section }}
            </b-form-checkbox>
          </b-form-checkbox-group>
        </b-form-group>

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
import { MESSAGE_LABELS } from "../../constants/terminology";
import { LOCKABLE_SECTIONS } from "../../composables/ruleFieldConfig";

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
      msg: MESSAGE_LABELS,
      comment: "",
      loading: false,
      lockMode: "full",
      selectedSections: [],
      sectionOptions: Object.keys(LOCKABLE_SECTIONS),
    };
  },
  computed: {
    okButtonText() {
      if (this.lockMode === "sections") {
        return `Lock ${this.selectedSections.length} section(s)`;
      }
      return this.msg.lockAllButton;
    },
  },
  methods: {
    showModal: function () {
      this.comment = "";
      this.lockMode = "full";
      this.selectedSections = [];
      this.$refs["LockControlsModal"].show();
    },
    handleOk: function (bvModalEvt) {
      if (bvModalEvt && bvModalEvt.preventDefault) {
        bvModalEvt.preventDefault();
      }

      if (!this.comment) {
        this.$bvToast.toast("Please enter a comment", {
          title: "Error",
          variant: "danger",
          solid: true,
        });
        return;
      }

      if (this.lockMode === "full") {
        this.lockControls();
      } else {
        this.lockSections();
      }
    },
    lockControls: function () {
      this.loading = true;
      axios
        .post(`/components/${this.component_id}/lock`, {
          review: { action: "lock_control", comment: this.comment },
        })
        .then(this.lockControlsSuccess)
        .catch(this.alertOrNotifyResponse)
        .finally(this.completeLoading);
    },
    lockSections: function () {
      this.loading = true;
      axios
        .patch(`/components/${this.component_id}/lock_sections`, {
          sections: this.selectedSections,
          locked: true,
          comment: this.comment,
        })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.$refs["LockControlsModal"].hide();
          this.$emit("projectUpdated");
        })
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
