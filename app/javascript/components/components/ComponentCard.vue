<template>
  <b-overlay :show="showDeleteConfirmation" class="m-3" :opacity="0.95">
    <!-- Overlay content -->
    <template #overlay>
      <div class="text-center">
        <p>Are you sure you want to remove this component from the project?</p>
        <b-button variant="outline-secondary" @click="showDeleteConfirmation = false">
          Cancel
        </b-button>
        <b-button variant="danger" @click="$emit('deleteComponent', component.id)">Remove</b-button>
      </div>
    </template>

    <!-- Card -->
    <b-card class="shadow">
      <b-card-title>
        {{ component.child_project_name }}
        <span class="float-right h6">{{ component.rule_count }} Controls</span>
      </b-card-title>
      <b-card-sub-title class="mb-2">Based on SRG-00000 Version</b-card-sub-title>
      <p>
        <span v-if="component.project_admin_name">
          {{ component.project_admin_name }}
          {{ component.project_admin_email ? `(${component.project_admin_email})` : "" }}
        </span>
        <em v-else>No Project Admin</em>
        <a :href="`/projects/${component.child_project_id}`" target="_blank" class="text-body">
          <i class="mdi mdi-open-in-new float-right h5 clickable" aria-hidden="true" />
        </a>
        <i
          v-if="component.id"
          class="mdi mdi-delete float-right h5 clickable mr-2"
          aria-hidden="true"
          @click="showDeleteConfirmation = !showDeleteConfirmation"
        />
      </p>
    </b-card>
  </b-overlay>
</template>

<script>
export default {
  name: "ComponentCard",
  props: {
    component: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return {
      showDeleteConfirmation: false,
    };
  },
};
</script>

<style scoped></style>
