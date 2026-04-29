<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />
    <div class="px-3">
      <div class="d-flex justify-content-between align-items-center mb-3">
        <div>
          <h1 class="h3 mb-1">Project Triage Queue</h1>
          <p class="text-muted mb-0">
            All public-comment-review activity across {{ project.name }} components.
          </p>
        </div>
        <div>
          <b-button :href="`/projects/${project.id}`" variant="outline-secondary" size="sm">
            <b-icon icon="arrow-left" /> Back to Project
          </b-button>
        </div>
      </div>
      <ComponentComments
        scope="project"
        :project-id="project.id"
        :effective-permissions="effectivePermissions"
      />
    </div>
  </div>
</template>

<script>
import ComponentComments from "../components/ComponentComments.vue";

export default {
  name: "ProjectTriagePage",
  components: { ComponentComments },
  props: {
    project: { type: Object, required: true },
    effectivePermissions: { type: String, default: null },
    currentUserId: { type: Number, required: true },
  },
  computed: {
    breadcrumbs() {
      return [
        { text: "Projects", href: "/projects" },
        { text: this.project.name, href: `/projects/${this.project.id}` },
        { text: "Triage", active: true },
      ];
    },
  },
};
</script>
