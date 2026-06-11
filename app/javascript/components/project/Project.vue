<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <!-- Command Bar -->
    <ProjectCommandBar
      ref="commandBar"
      :project="project"
      :active-panel="activePanel"
      @toggle-visibility="showVisibilityConfirm"
      @new-component="openNewComponentModal"
      @download="openExportModal"
      @open-members="openMembersModal"
      @toggle-panel="togglePanel"
    />

    <!-- Visibility Confirmation Modal -->
    <b-modal
      id="confirm-visibility-change"
      v-model="showVisibilityModal"
      title="Confirm Visibility Change"
      @ok="updateVisibility"
      @cancel="cancelVisibilityChange"
      @hidden="onVisibilityModalHidden"
    >
      Are you sure you want to change the visibility of this project to
      <mark>{{ pendingVisibility ? "discoverable" : "hidden" }}</mark
      >?
    </b-modal>

    <!-- Main Content (full width, no right sidebar) -->
    <b-row class="mt-3">
      <b-col md="12">
        <!-- Tab view for project information -->
        <b-tabs v-model="projectTabIndex" content-class="mt-3" justified>
          <!-- Project components -->
          <b-tab :title="`Components (${project.components.length})`">
            <h2>Project Components</h2>
            <p v-if="sortedRegularComponents().length === 0" class="text-muted">
              No components yet. Click <strong>New Component</strong> to get started.
            </p>
            <b-row cols="1" cols-sm="1" cols-md="1" cols-lg="2">
              <b-col v-for="component in sortedRegularComponents()" :key="component.id">
                <ComponentCard
                  :component="component"
                  @deleteComponent="deleteComponent($event)"
                  @projectUpdated="refreshProject"
                />
              </b-col>
            </b-row>

            <h2 class="mt-5">Overlaid Components</h2>
            <p v-if="sortedOverlayComponents().length === 0" class="text-muted">
              No overlaid components. To add one, click
              <strong>New Component</strong> → <strong>Add Overlaid Component</strong>.
            </p>
            <b-row cols="1" cols-sm="1" cols-md="1" cols-lg="2">
              <b-col v-for="component in sortedOverlayComponents()" :key="component.id">
                <ComponentCard
                  :component="component"
                  @deleteComponent="deleteComponent($event)"
                  @projectUpdated="refreshProject"
                />
              </b-col>
            </b-row>
          </b-tab>

          <!-- Diff View -->
          <b-tab title="Diff Viewer" lazy>
            <DiffViewer :project="initialProjectState" />
          </b-tab>
        </b-tabs>
      </b-col>
    </b-row>

    <!-- Slideover Panels -->
    <ProjectSidepanels
      :project="project"
      :active-panel="activePanel"
      :unique-component-names="uniqueComponentNames"
      @close-panel="closePanel"
      @project-updated="refreshProject"
    />

    <!-- Component Action Picker (NEW) -->
    <ComponentActionPicker
      v-model="showComponentActionPicker"
      :show-restore="canAdmin"
      @next="handleComponentAction"
      @cancel="showComponentActionPicker = false"
    />

    <!-- Component Creation Modals (showOpener=false, triggered via refs) -->
    <NewComponentModal
      v-if="canAdmin"
      ref="newComponentModal"
      :project_id="project.id"
      :project="project"
      @projectUpdated="refreshProject"
    />
    <NewComponentModal
      v-if="canAdmin"
      ref="importComponentModal"
      :project_id="project.id"
      :project="project"
      :spreadsheet_import="true"
      @projectUpdated="refreshProject"
    />
    <NewComponentModal
      v-if="canAdmin"
      ref="copyComponentModal"
      :project_id="project.id"
      :project="project"
      :copy_component="true"
      @projectUpdated="refreshProject"
    />
    <AddComponentModal
      v-if="canAdmin"
      ref="addComponentModal"
      :project_id="project.id"
      :available_components="sortedAvailableComponents"
      @projectUpdated="refreshProject"
    />
    <RestoreBackupModal
      v-if="canAdmin"
      ref="restoreBackupModal"
      :project_id="project.id"
      @projectUpdated="refreshProject"
    />

    <!-- Project Members Modal -->
    <ProjectMembersModal :project="project" :available-roles="available_roles" />

    <!-- Export Modal (reusable) -->
    <ExportModal
      v-model="showExportModal"
      :components="project.components"
      :available-modes="exportModes"
      @export="executeExport"
      @cancel="showExportModal = false"
    />
  </div>
</template>

<script>
import { provide } from "vue";
import _ from "lodash";
import { getProject, updateProject, exportProjectData } from "../../api/projectsApi";
import { deleteComponent } from "../../api/componentsApi";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import { useSidebar } from "../../composables";
import { roleGteTo } from "../../utils/roleComparison";
import ComponentCard from "../components/ComponentCard.vue";
import AddComponentModal from "../components/AddComponentModal.vue";
import NewComponentModal from "../components/NewComponentModal.vue";
import DiffViewer from "./DiffViewer.vue";
import ProjectCommandBar from "./ProjectCommandBar.vue";
import ProjectSidepanels from "./ProjectSidepanels.vue";
import ExportModal from "../shared/ExportModal.vue";
import ProjectMembersModal from "./ProjectMembersModal.vue";
import ComponentActionPicker from "./ComponentActionPicker.vue";
import RestoreBackupModal from "./RestoreBackupModal.vue";

export default {
  name: "Project",
  components: {
    ComponentCard,
    AddComponentModal,
    NewComponentModal,
    DiffViewer,
    ProjectCommandBar,
    ProjectSidepanels,
    ExportModal,
    ProjectMembersModal,
    ComponentActionPicker,
    RestoreBackupModal,
  },
  // AlertMixin migrates with the toast architecture (useToast). DateFormat/Form mixins were dead
  // imports (friendlyDateTime/authenticityToken never consumed here);
  // RoleComparison is replaced by the roleGteTo util in setup — Project.vue
  // is the permissions PROVIDER and cannot inject its own provide.
  mixins: [AlertMixinVue],
  props: {
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
    available_roles: {
      type: Array,
      required: true,
    },
  },
  setup(props) {
    const { activePanel, togglePanel, closePanel } = useSidebar();

    const effective_permissions = props.initialProjectState?.effective_permissions || null;
    provide("effectivePermissions", effective_permissions);

    // Provider side of the permissions contract — children inject via
    // usePermissions; Project.vue itself derives gates from the same util.
    const canAdmin = roleGteTo(effective_permissions, "admin");

    return { activePanel, togglePanel, closePanel, effective_permissions, canAdmin };
  },
  data: function () {
    return {
      project: this.initialProjectState,
      projectTabIndex: 0,
      // Export modal state
      showExportModal: false,
      // Component action picker state
      showComponentActionPicker: false,
      // Visibility modal state
      showVisibilityModal: false,
      pendingVisibility: false,
    };
  },
  computed: {
    exportModes() {
      return ["working_copy", "vendor_submission", "published_stig", "backup"];
    },
    sortedAvailableComponents: function () {
      return _.sortBy(this.project.available_components, ["child_project_name"], ["asc"]);
    },
    uniqueComponentNames: function () {
      return _.uniq(this.sortedComponents().map((c) => c["name"]));
    },
    adminList: function () {
      return this.project.admins.map((a) => `${a.name} <${a.email}>`).join(", ");
    },
    lastAudit: function () {
      return this.project.histories.slice(0, 1).pop();
    },
    breadcrumbs: function () {
      return [
        {
          text: "Projects",
          href: "/projects",
        },
        {
          text: this.project.name,
          active: true,
        },
      ];
    },
  },
  watch: {
    projectTabIndex: function (_) {
      localStorage.setItem(
        `projectTabIndex-${this.project.id}`,
        JSON.stringify(this.projectTabIndex),
      );
    },
  },
  mounted: function () {
    // Persist `currentTab` across page loads
    if (localStorage.getItem(`projectTabIndex-${this.project.id}`)) {
      try {
        this.$nextTick(
          () =>
            (this.projectTabIndex = JSON.parse(
              localStorage.getItem(`projectTabIndex-${this.project.id}`),
            )),
        );
      } catch (e) {
        localStorage.removeItem(`projectTabIndex-${this.project.id}`);
      }
    }

    // Auto-open members modal when linked from access request notification
    const params = new URLSearchParams(window.location.search);
    if (params.get("members")) {
      this.$nextTick(() => this.openMembersModal());
    }
  },
  methods: {
    sortedComponents: function () {
      return _.orderBy(
        this.project.components,
        [(component) => (component.name || "").toLowerCase(), "version", "release"],
        ["asc"],
      );
    },
    sortedOverlayComponents: function () {
      return this.sortedComponents().filter((e) => e.component_id != null);
    },
    sortedRegularComponents: function () {
      return this.sortedComponents().filter((e) => e.component_id == null);
    },
    refreshProject: function () {
      getProject(this.project.id).then((response) => {
        this.project = response.data;
        this.visible = this.project.visibility === "discoverable";
      });
    },
    showVisibilityConfirm(newValue) {
      this.pendingVisibility = newValue;
      this.showVisibilityModal = true;
    },
    updateVisibility: function () {
      this.showVisibilityModal = false;
      updateProject(this.project.id, {
        visibility: this.pendingVisibility ? "discoverable" : "hidden",
      })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.refreshProject();
        })
        .catch(this.alertOrNotifyResponse);
    },
    cancelVisibilityChange() {
      this.showVisibilityModal = false;
      // Reset the command bar toggle to match actual project state
      if (this.$refs.commandBar) {
        this.$refs.commandBar.resetVisibilityToggle();
      }
    },
    onVisibilityModalHidden() {
      // Also reset on any modal close (backdrop click, escape key)
      if (this.$refs.commandBar) {
        this.$refs.commandBar.resetVisibilityToggle();
      }
    },
    openNewComponentModal() {
      this.showComponentActionPicker = true;
    },
    handleComponentAction(actionType) {
      // Route to appropriate modal based on action type
      switch (actionType) {
        case "create":
          if (this.$refs.newComponentModal) {
            this.$refs.newComponentModal.showModal();
          }
          break;
        case "import":
          if (this.$refs.importComponentModal) {
            this.$refs.importComponentModal.showModal();
          }
          break;
        case "copy":
          if (this.$refs.copyComponentModal) {
            this.$refs.copyComponentModal.showModal();
          }
          break;
        case "overlay":
          if (this.$refs.addComponentModal) {
            this.$refs.addComponentModal.showModal();
          }
          break;
        case "restore":
          if (this.$refs.restoreBackupModal) {
            this.$refs.restoreBackupModal.showModal();
          }
          break;
      }
    },
    openExportModal() {
      this.showExportModal = true;
    },
    openMembersModal() {
      this.$bvModal.show("project-members-modal");
    },
    executeExport({
      type,
      mode,
      componentIds,
      includeSrg,
      includeMemberships,
      excludeSatisfiedBy,
    }) {
      // Called by ExportModal when user confirms export
      this.downloadExport(
        type,
        componentIds,
        mode,
        includeSrg,
        includeMemberships,
        excludeSatisfiedBy,
      );
    },
    // Having deleteComponent on the `ComponentCard` causes it to
    // disappear almost immediately because the component gets
    // destroyed once `refreshProject` executes
    deleteComponent: function (componentId) {
      deleteComponent(componentId)
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.refreshProject();
        })
        .catch(this.alertOrNotifyResponse);
    },
    downloadExport: function (
      type,
      componentIds,
      mode,
      includeSrg,
      includeMemberships,
      excludeSatisfiedBy,
    ) {
      exportProjectData(this.project.id, type, {
        componentIds,
        mode,
        includeSrg,
        includeMemberships,
        excludeSatisfiedBy,
      })
        .then((url) => {
          window.open(url);
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>

<style scoped></style>
