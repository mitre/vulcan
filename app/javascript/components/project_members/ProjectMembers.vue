<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />
    <h1>{{ project.name }} - Manage Project Members</h1>
    <ProjectMembersTable
      :editable="true"
      :project="project"
      :project_members="project_members"
      :available_members="available_members"
      :available_roles="available_roles"
      :project_members_count="project_members_count"
    />
  </div>
</template>

<script>
import ProjectMembersTable from "./ProjectMembersTable.vue";

export default {
  name: "ProjectMembers",
  components: { ProjectMembersTable },
  props: {
    project_members: {
      type: Array,
      required: true,
    },
    project: {
      type: Object,
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
    project_members_count: {
      type: Number,
      required: true,
    },
  },
  computed: {
    breadcrumbs: function () {
      return [
        {
          text: "Projects",
          href: "/projects",
        },
        {
          text: this.project.name,
          href: "/projects/" + this.project.id,
        },
        {
          text: "Project Members",
          active: true,
        },
      ];
    },
  },
};
</script>

<style scoped></style>
