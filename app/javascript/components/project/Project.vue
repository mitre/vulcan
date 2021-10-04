<template>
  <div>
    <ComponentShow
      v-if="initialProjectState.component"
      :project_permissions="project_permissions"
      :initial-project-state="initialProjectState"
      :current_user_id="current_user_id"
      :statuses="statuses"
      :severities="severities"
      :available_members="available_members"
      :available_roles="available_roles"
    />

    <ProjectShow
      v-else
      :project_permissions="project_permissions"
      :initial-project-state="initialProjectState"
      :current_user_id="current_user_id"
      :statuses="statuses"
      :severities="severities"
      :available_members="available_members"
      :available_roles="available_roles"
    />
  </div>
</template>

<script>
import ProjectShow from "./ProjectShow.vue";
import ComponentShow from "../components/ComponentShow.vue";

export default {
  name: "Project",
  components: {
    ProjectShow,
    ComponentShow,
  },
  props: {
    project_permissions: {
      type: String,
    },
    initialProjectState: {
      type: Object,
      required: true,
    },
    current_user_id: {
      type: Number,
    },
    statuses: {
      type: Array,
      required: true,
    },
    severities: {
      type: Array,
      required: true,
    },
    available_members: {
      type: Array,
      required: true,
    },
    available_roles: {
      type: Array,
      required: true,
    },
  },
};
</script>

<style scoped></style>
