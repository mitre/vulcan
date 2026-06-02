<template>
  <div v-if="projectId" class="response-template-dropdown mb-2">
    <b-form-select
      v-model="picked"
      :options="options"
      size="sm"
      :disabled="loading"
      data-testid="template-picker"
      aria-label="Insert response template"
      @change="onChange"
    />
  </div>
</template>

<script>
import { getTriageResponseTemplates } from "../../api/projectsApi";

export default {
  name: "ResponseTemplateDropdown",
  props: {
    projectId: { type: [Number, String], default: null },
  },
  data() {
    return {
      templates: [],
      loading: false,
      picked: null,
    };
  },
  computed: {
    options() {
      const head = this.templates.length
        ? {
            value: null,
            text: this.loading ? "Loading templates…" : "Insert template…",
            disabled: true,
          }
        : {
            value: null,
            text: this.loading ? "Loading templates…" : "No templates yet",
            disabled: true,
          };
      return [head, ...this.templates.map((t) => ({ value: t.id, text: t.name }))];
    },
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
    onChange(id) {
      if (id == null) return;
      const t = this.templates.find((x) => x.id === id);
      if (t) this.$emit("insert", t.body);
      // Reset to the placeholder so re-selecting the same template re-fires.
      this.$nextTick(() => {
        this.picked = null;
      });
    },
  },
};
</script>
