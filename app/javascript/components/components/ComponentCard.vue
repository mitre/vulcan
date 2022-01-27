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
        {{ component.version }}
        <i v-if="component.released" class="mdi mdi-stamper h5" aria-hidden="true" />
        <!-- Rules count info -->
        <span class="float-right h6">
          {{ component.rules_count }} {{ component.component_id ? "Overlayed" : "" }} Controls
        </span>
      </b-card-title>
      <b-card-sub-title class="mb-2">
        Based on {{ component.based_on_title }} {{ component.based_on_version }}
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
          <a :href="`/components/${component.id}/export`" target="_blank" class="text-body">
            <i
              v-b-tooltip.hover
              class="mdi mdi-download h5 float-right mr-2 clickable"
              aria-hidden="true"
              title="Export Component"
            />
          </a>

          <!-- Lock all controls in component -->
          <span v-if="actionable && effectivePermissions == 'admin'" class="float-right mr-2">
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
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import ConfirmComponentReleaseMixin from "../../mixins/ConfirmComponentReleaseMixin.vue";
import LockControlsModal from "../components/LockControlsModal.vue";
import NewComponentModal from "../components/NewComponentModal.vue";

export default {
  name: "ComponentCard",
  components: {
    LockControlsModal,
    NewComponentModal,
  },
  mixins: [AlertMixinVue, FormMixinVue, ConfirmComponentReleaseMixin],
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
};
</script>

<style scoped></style>
