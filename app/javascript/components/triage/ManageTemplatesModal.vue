<template>
  <b-modal
    :visible="visible"
    title="Response Templates"
    size="xl"
    centered
    hide-footer
    modal-class="manage-templates-modal"
    @hidden="$emit('update:visible', false)"
  >
    <div v-if="loading" class="text-center py-3">
      <b-spinner small />
    </div>

    <template v-else>
      <div v-if="templates.length" class="mb-3">
        <div
          v-for="t in templates"
          :key="t.id"
          class="d-flex align-items-start py-2 border-bottom"
          data-testid="template-row"
        >
          <template v-if="editingId === t.id">
            <div class="flex-grow-1 mr-2">
              <b-form-input v-model="editName" size="sm" class="mb-1" placeholder="Template name" />
              <MarkdownTextarea v-model="editBody" placeholder="Template body" />
            </div>
            <b-button size="sm" variant="outline-primary" class="mr-1" @click="saveEdit(t.id)">
              Save
            </b-button>
            <b-button size="sm" variant="outline-secondary" @click="cancelEdit"> Cancel </b-button>
          </template>

          <template v-else>
            <div class="flex-grow-1">
              <strong>{{ t.name }}</strong>
              <p class="mb-0 small text-muted white-space-pre-wrap">{{ t.body }}</p>
            </div>
            <b-button
              size="sm"
              variant="outline-secondary"
              class="mr-1"
              data-testid="edit-template-btn"
              @click="startEdit(t)"
            >
              <b-icon icon="pencil" />
            </b-button>
            <b-button
              size="sm"
              variant="outline-danger"
              data-testid="delete-template-btn"
              @click="onDelete(t)"
            >
              <b-icon icon="trash" />
            </b-button>
          </template>
        </div>
      </div>

      <p v-else class="text-muted small">No templates yet. Create one below.</p>

      <div class="border rounded p-3" style="background-color: var(--vulcan-tertiary-bg)">
        <h6 class="mb-2">New Template</h6>
        <b-form-input
          v-model="newName"
          size="sm"
          class="mb-2"
          placeholder="Template name"
          data-testid="new-template-name"
        />
        <MarkdownTextarea
          v-model="newBody"
          class="mb-2"
          placeholder="Response text (markdown supported)"
          data-testid="new-template-body"
        />
        <b-button
          variant="outline-primary"
          size="sm"
          :disabled="!newName.trim() || !newBody.trim()"
          data-testid="create-template-btn"
          @click="onCreate"
        >
          Save Template
        </b-button>
      </div>
    </template>
  </b-modal>
</template>

<script>
import {
  getTriageResponseTemplates,
  createTriageResponseTemplate,
  updateTriageResponseTemplate,
  deleteTriageResponseTemplate,
} from "../../api/projectsApi";
import MarkdownTextarea from "../shared/MarkdownTextarea.vue";

export default {
  name: "ManageTemplatesModal",
  components: { MarkdownTextarea },
  props: {
    projectId: { type: [Number, String], required: true },
    visible: { type: Boolean, default: false },
  },
  data() {
    return {
      templates: [],
      loading: false,
      newName: "",
      newBody: "",
      editingId: null,
      editName: "",
      editBody: "",
    };
  },
  watch: {
    visible: {
      immediate: true,
      handler(val) {
        if (val) this.fetch();
      },
    },
  },
  methods: {
    async fetch() {
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
    async onCreate() {
      if (!this.newName.trim() || !this.newBody.trim()) return;
      await createTriageResponseTemplate(this.projectId, {
        name: this.newName.trim(),
        body: this.newBody.trim(),
      });
      this.newName = "";
      this.newBody = "";
      await this.fetch();
      this.$emit("saved");
    },
    startEdit(t) {
      this.editingId = t.id;
      this.editName = t.name;
      this.editBody = t.body;
    },
    cancelEdit() {
      this.editingId = null;
      this.editName = "";
      this.editBody = "";
    },
    async saveEdit(id) {
      await updateTriageResponseTemplate(this.projectId, id, {
        name: this.editName.trim(),
        body: this.editBody.trim(),
      });
      this.cancelEdit();
      await this.fetch();
      this.$emit("saved");
    },
    async onDelete(t) {
      await deleteTriageResponseTemplate(this.projectId, t.id);
      await this.fetch();
      this.$emit("saved");
    },
  },
};
</script>

<style scoped>
.white-space-pre-wrap {
  white-space: pre-wrap;
}
</style>

<style>
.manage-templates-modal .CodeMirror {
  min-height: 12rem;
}
</style>
