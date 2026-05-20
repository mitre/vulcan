<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <BaseCommandBar>
      <template #left>
        <b-button
          v-if="isSplitMode"
          variant="outline-secondary"
          size="sm"
          class="mr-2"
          @click="exitSplit"
        >
          <b-icon icon="arrow-left" /> Back to Comments Table
        </b-button>
        <b-button :href="`/components/${component.id}`" variant="outline-secondary" size="sm">
          <b-icon icon="arrow-left" /> Back to Component Editor
        </b-button>
      </template>
      <template #right />
    </BaseCommandBar>

    <div class="px-3">
      <div class="mb-3">
        <h1 class="h3 mb-1">Comments</h1>
        <p class="text-muted mb-0">
          <strong>{{ component.name }}</strong>
          <span v-if="component.version || component.release" class="ml-1">
            v{{ component.version }}r{{ component.release }}
          </span>
          <span class="ml-2">— {{ project.name }}</span>
        </p>
      </div>
      <ComponentComments
        ref="comments"
        scope="component"
        :component-id="component.id"
        :component-displayed-name="component.name"
        :effective-permissions="effectivePermissions"
        :admin-panel-open="adminPanelOpen"
        :context-mode.sync="contextMode"
        @split-mode-changed="onSplitModeChanged"
        @admin-panel-close="adminPanelOpen = false"
      />
    </div>
  </div>
</template>

<script>
import BaseCommandBar from "../shared/BaseCommandBar.vue";
import ComponentComments from "./ComponentComments.vue";

export default {
  name: "ComponentTriagePage",
  components: { BaseCommandBar, ComponentComments },
  props: {
    initialComponentState: { type: Object, required: true },
    project: { type: Object, required: true },
    effectivePermissions: { type: String, default: null },
    currentUserId: { type: Number, required: true },
  },
  data() {
    return {
      component: this.initialComponentState,
      isSplitMode: false,
      adminPanelOpen: false,
      contextMode: "commented",
    };
  },
  computed: {
    isAdmin() {
      return this.effectivePermissions === "admin";
    },
    breadcrumbs() {
      return [
        { text: "Projects", href: "/projects" },
        { text: this.project.name, href: `/projects/${this.project.id}` },
        { text: this.component.name, href: `/components/${this.component.id}` },
        { text: "Comments", active: true },
      ];
    },
  },
  methods: {
    onSplitModeChanged(val) {
      this.isSplitMode = val;
      if (!val) this.adminPanelOpen = false;
    },
    exitSplit() {
      this.isSplitMode = false;
      this.adminPanelOpen = false;
      if (this.$refs.comments) {
        this.$refs.comments.exitSplitMode();
      }
    },
  },
};
</script>
