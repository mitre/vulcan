<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />
    <div class="px-3">
      <div class="d-flex justify-content-between align-items-center mb-3">
        <div>
          <h1 class="h3 mb-1">Triage Queue</h1>
          <p class="text-muted mb-0">
            <strong>{{ component.name }}</strong>
            <span v-if="component.version || component.release" class="ml-1">
              v{{ component.version }}r{{ component.release }}
            </span>
            <span class="ml-2">— {{ project.name }}</span>
          </p>
        </div>
        <div>
          <b-button :href="`/components/${component.id}`" variant="outline-secondary" size="sm">
            <b-icon icon="arrow-left" /> Back to Component Editor
          </b-button>
        </div>
      </div>
      <ComponentComments
        scope="component"
        :component-id="component.id"
        :component-displayed-name="component.name"
        :effective-permissions="effectivePermissions"
      />
    </div>
  </div>
</template>

<script>
import ComponentComments from "./ComponentComments.vue";

export default {
  name: "ComponentTriagePage",
  components: { ComponentComments },
  props: {
    initialComponentState: { type: Object, required: true },
    project: { type: Object, required: true },
    effectivePermissions: { type: String, default: null },
    currentUserId: { type: Number, required: true },
  },
  data() {
    return {
      component: this.initialComponentState,
    };
  },
  computed: {
    breadcrumbs() {
      return [
        { text: "Projects", href: "/projects" },
        { text: this.project.name, href: `/projects/${this.project.id}` },
        { text: this.component.name, href: `/components/${this.component.id}` },
        { text: "Triage", active: true },
      ];
    },
  },
};
</script>
