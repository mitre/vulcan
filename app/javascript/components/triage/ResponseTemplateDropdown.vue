<template>
  <div v-if="projectId" class="response-template-dropdown mb-2">
    <b-dropdown
      :text="loading ? 'Loading…' : templates.length ? 'Insert template…' : 'No templates yet'"
      size="sm"
      variant="outline-secondary"
      :disabled="loading && !templates.length"
      data-testid="template-picker"
      aria-label="Insert response template"
      boundary="viewport"
    >
      <b-dropdown-item-button v-for="t in templates" :key="t.id" @click="onSelect(t)">
        {{ t.name }}
      </b-dropdown-item-button>

      <template v-if="canManage">
        <b-dropdown-divider />
        <b-dropdown-item-button data-testid="manage-templates-btn" @click="showManage = true">
          <b-icon icon="gear" class="mr-1" />
          Manage templates…
        </b-dropdown-item-button>
      </template>
    </b-dropdown>

    <ManageTemplatesModal
      v-if="canManage"
      :project-id="projectId"
      :visible="showManage"
      @update:visible="showManage = $event"
      @saved="fetch"
    />
  </div>
</template>

<script>
import { getTriageResponseTemplates } from "../../api/projectsApi";
import ManageTemplatesModal from "./ManageTemplatesModal.vue";

export default {
  name: "ResponseTemplateDropdown",
  components: { ManageTemplatesModal },
  props: {
    projectId: { type: [Number, String], default: null },
    canManage: { type: Boolean, default: false },
  },
  data() {
    return {
      templates: [],
      loading: false,
      showManage: false,
    };
  },
  watch: {
    projectId: { immediate: true, handler: "fetch" },
  },
  methods: {
    async fetch() {
      if (!this.projectId) {
        this.templates = [];
        return;
      }
      this.loading = true;
      try {
        const { data } = await getTriageResponseTemplates(this.projectId);
        this.templates = data?.triage_response_templates || [];
      } catch {
        this.templates = [];
      } finally {
        this.loading = false;
      }
    },
    onSelect(t) {
      this.$emit("insert", t.body);
    },
  },
};
</script>
