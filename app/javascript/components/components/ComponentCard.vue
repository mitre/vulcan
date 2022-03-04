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
        {{ component.name }}
        <span v-if="component.version || component.release">
          &nbsp;-
          <span v-if="component.version"> &nbsp;Version {{ component.version }} </span>
          <span v-if="component.release"> &nbsp;Release {{ component.release }} </span>
        </span>
        <i v-if="component.released" class="mdi mdi-stamper h5" aria-hidden="true" />
        <!-- Rules count info -->
        <span class="float-right h6">
          {{ component.rules_count }} {{ component.component_id ? "Overlaid" : "" }} Controls
        </span>
      </b-card-title>
      <b-card-sub-title class="mb-2">
        Based on {{ component.based_on_title }} {{ component.based_on_version }}
      </b-card-sub-title>
      <b-card-sub-title v-if="component.description" class="my-2">
        {{ component.description }}
      </b-card-sub-title>
      <p>
        <span v-if="component.admin_name">
          {{ component.admin_name }}
          {{ component.admin_email ? `(${component.admin_email})` : "" }}
        </span>
        <em v-else>No Component Admin</em>

        <!-- Component actions -->
        <span>
          <!-- Open component -->
          <a :href="`/components/${component.id}`" target="_blank" class="text-body">
            <i
              v-b-tooltip.hover
              class="mdi mdi-open-in-new float-right h5 clickable"
              aria-hidden="true"
              title="Open Component"
            />
          </a>

          <!-- Remove component -->
          <i
            v-if="actionable && component.id && effectivePermissions == 'admin'"
            v-b-tooltip.hover
            class="mdi mdi-delete float-right h5 clickable mr-2"
            aria-hidden="true"
            title="Remove Component"
            @click="showDeleteConfirmation = !showDeleteConfirmation"
          />

          <!-- Duplicate component -->
          <span v-if="actionable && effectivePermissions == 'admin'" class="float-right mr-2">
            <NewComponentModal
              :component_to_duplicate="component.id"
              :project_id="component.project_id"
              :predetermined_prefix="component.prefix"
              :predetermined_security_requirements_guide_id="
                component.security_requirements_guide_id
              "
              @projectUpdated="$emit('projectUpdated')"
            >
              <template #opener>
                <i
                  v-if="component.id"
                  v-b-tooltip.hover
                  class="mdi mdi-content-copy h5 clickable"
                  aria-hidden="true"
                  title="Duplicate component and create a new version"
                />
              </template>
            </NewComponentModal>
          </span>

          <!-- Release component -->
          <span
            v-if="actionable && component.id && effectivePermissions == 'admin'"
            class="float-right mr-2"
          >
            <span v-b-tooltip.hover :title="releaseComponentTooltip">
              <i
                :class="releaseComponentClasses"
                aria-hidden="true"
                @click="confirmComponentRelease"
              />
            </span>
          </span>

          <!-- Export component -->
          <i
            v-b-tooltip.hover
            class="mdi mdi-download h5 float-right mr-2 clickable"
            aria-hidden="true"
            title="Export Component as CSV"
            @click="downloadExport('csv')"
          />

          <!-- Download InSpec Profile -->
          <i
            v-b-tooltip.hover
            class="inspec-icon h5 float-right mr-2 clickable"
            aria-hidden="true"
            title="Download InSpec Profile"
            @click="downloadExport('inspec')"
          />

          <!-- Lock all controls in component -->
          <span
            v-if="actionable && role_gte_to(effectivePermissions, 'reviewer')"
            class="float-right mr-2"
          >
            <LockControlsModal
              :component_id="component.id"
              @projectUpdated="$emit('projectUpdated')"
            >
              <template #opener>
                <i
                  v-if="component.id"
                  v-b-tooltip.hover
                  class="mdi mdi-lock h5 clickable"
                  aria-hidden="true"
                  title="Lock component controls"
                />
              </template>
            </LockControlsModal>
          </span>
        </span>
      </p>
    </b-card>
  </b-overlay>
</template>

<script>
import axios from "axios";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import ConfirmComponentReleaseMixin from "../../mixins/ConfirmComponentReleaseMixin.vue";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import LockControlsModal from "../components/LockControlsModal.vue";
import NewComponentModal from "../components/NewComponentModal.vue";

export default {
  name: "ComponentCard",
  components: {
    LockControlsModal,
    NewComponentModal,
  },
  mixins: [AlertMixinVue, FormMixinVue, ConfirmComponentReleaseMixin, RoleComparisonMixin],
  props: {
    // Indicate if the card is for "read-only" or can take actions against it
    actionable: {
      type: Boolean,
      default: true,
    },
    effectivePermissions: {
      type: String,
      required: false,
    },
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
  computed: {
    releaseComponentClasses: function () {
      let classes = ["mdi", "mdi-stamper", "h5", "clickable"];
      if (!this.component.releasable) {
        classes.push("text-muted");
      }
      return classes;
    },
    releaseComponentTooltip: function () {
      if (this.component.released) {
        return "Component has already been released";
      }

      if (this.component.releasable) {
        return "Release Component";
      }

      return "All rules must be locked to release a component";
    },
  },
  methods: {
    downloadExport: function (type) {
      axios
        .get(`/components/${this.component.id}/export/${type}`)
        .then((_res) => {
          // Once it is validated that there is content to download, prompt
          // the user to save the file
          window.open(`/components/${this.component.id}/export/${type}`);
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>

<style scoped>
.inspec-icon {
  background: url("data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4KPHN2ZyB3aWR0aD0iMzJweCIgaGVpZ2h0PSIzMnB4IiB2aWV3Qm94PSIwIDAgMzIgMzIiIHZlcnNpb249IjEuMSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KICA8dGl0bGU+QXJ0Ym9hcmQ8L3RpdGxlPgogIDxkZXNjPkNyZWF0ZWQgd2l0aCBTa2V0Y2guPC9kZXNjPgogIDxnIGlkPSJBcnRib2FyZCIgc3Ryb2tlPSJub25lIiBzdHJva2Utd2lkdGg9IjEiIGZpbGw9Im5vbmUiIGZpbGwtcnVsZT0iZXZlbm9kZCI+CiAgICA8ZyBpZD0iR3JvdXAtMyIgZmlsbD0iIzQ0OUJCQiI+CiAgICAgIDxwYXRoIGQ9Ik02LjQ5MjkyNzkzLDI4Ljg3MDQ0OTUgTDExLjg5MTQzODcsMjQuMDA5NjA4NyBDMTMuMTIzMTM2NSwyNC42NDI2ODU4IDE0LjUxOTg0MDcsMjUgMTYsMjUgQzIwLjk3MDU2MjcsMjUgMjUsMjAuOTcwNTYyNyAyNSwxNiBDMjUsMTEuMDI5NDM3MyAyMC45NzA1NjI3LDcgMTYsNyBDMTEuMDI5NDM3Myw3IDcsMTEuMDI5NDM3MyA3LDE2IEM3LDE3LjY2Njg0NzYgNy40NTMxMzIzMiwxOS4yMjc4NjA0IDguMjQyOTMyODYsMjAuNTY2NTc0NCBMMi45ODE2NDIzNywyNS4zMDM4NjE2IEMxLjEwNDcxMzgzLDIyLjY4MjI2MDIgMCwxOS40NzAxNCAwLDE2IEMwLDcuMTYzNDQ0IDcuMTYzNDQ0LDAgMTYsMCBDMjQuODM2NTU2LDAgMzIsNy4xNjM0NDQgMzIsMTYgQzMyLDI0LjgzNjU1NiAyNC44MzY1NTYsMzIgMTYsMzIgQzEyLjQzOTY2ODEsMzIgOS4xNTA5NDI1NCwzMC44MzcxMTUgNi40OTI5Mjc5MywyOC44NzA0NDk1IFoiIGlkPSJDb21iaW5lZC1TaGFwZSIgc3R5bGU9ImZpbGw6IHJnYmEoMCwgMCwgMCwgMC44KTsiLz4KICAgICAgPGNpcmNsZSBpZD0iT3ZhbCIgY3g9IjE2IiBjeT0iMTYiIHI9IjUuMjUiIHN0eWxlPSJmaWxsOiByZ2JhKDAsIDAsIDAsIDAuOCk7Ii8+CiAgICA8L2c+CiAgPC9nPgo8L3N2Zz4=");
  background-size: 100%;
  height: 1rem;
  width: 1rem;
  margin: 0.1875rem 0;
  display: block;
}
</style>
