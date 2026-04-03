<template>
  <b-modal
    :visible="visible"
    title="Create New Project"
    size="lg"
    centered
    @hidden="onHidden"
    @ok="onSubmit"
  >
    <b-form @submit.prevent="onSubmit">
      <!-- Name -->
      <b-form-group label="Project Title" label-for="project-name">
        <b-form-input
          id="project-name"
          v-model="form.name"
          placeholder="Project Title"
          required
          autocomplete="off"
        />
      </b-form-group>

      <!-- Description -->
      <b-form-group label="Project Description" label-for="project-description">
        <b-form-textarea
          id="project-description"
          v-model="form.description"
          placeholder="Project Description"
          required
          autocomplete="off"
          rows="3"
        />
      </b-form-group>

      <!-- Visibility -->
      <b-form-group
        label="Visibility"
        label-for="project-visibility"
        description="Marking the project as discoverable means non-members can see it and request access."
      >
        <b-form-select
          id="project-visibility"
          v-model="form.visibility"
          :options="['discoverable', 'hidden']"
          required
        />
      </b-form-group>

      <!-- Slack Channel (optional) -->
      <b-form-group
        label="Slack Channel ID (Optional)"
        label-for="project-slack"
        description="For slack notifications about project activities"
      >
        <b-form-input
          id="project-slack"
          v-model="form.slack_channel_id"
          placeholder="Example: C123456, #general"
          autocomplete="off"
        />
      </b-form-group>
    </b-form>
  </b-modal>
</template>

<script>
import axios from "axios";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "NewProjectModal",
  mixins: [FormMixinVue, AlertMixinVue],
  model: {
    prop: "visible",
    event: "update:visible",
  },
  props: {
    visible: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      form: {
        name: "",
        description: "",
        visibility: "hidden",
        slack_channel_id: "",
      },
    };
  },
  watch: {
    visible(newVal) {
      if (newVal) {
        // Reset form when modal opens
        this.form = {
          name: "",
          description: "",
          visibility: "hidden",
          slack_channel_id: "",
        };
      }
    },
  },
  methods: {
    async onSubmit(event) {
      if (event) event.preventDefault();

      try {
        const response = await axios.post("/projects", {
          project: this.form,
        });
        this.alertOrNotifyResponse(response);
        this.$emit("project-created");
        this.$emit("update:visible", false);
      } catch (error) {
        this.alertOrNotifyResponse(error);
      }
    },
    onHidden() {
      this.$emit("update:visible", false);
    },
  },
};
</script>
