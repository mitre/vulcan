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
        <i v-if="component.released" class="mdi mdi-stamper h5 clickable" aria-hidden="true" />
        <span class="float-right h6"
          >{{ component.rule_count }} {{ component.component_id ? "Overlayed" : "" }} Controls</span
        >
      </b-card-title>
      <b-card-sub-title class="mb-2"
        >Based on {{ component.based_on_title }} {{ component.based_on_version }}</b-card-sub-title
      >
      <p>
        <span v-if="component.project_admin_name">
          {{ component.project_admin_name }}
          {{ component.project_admin_email ? `(${component.project_admin_email})` : "" }}
        </span>
        <em v-else>No Project Admin</em>

        <!-- Component actions -->
        <span v-if="actionable">
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
            v-if="component.id && effectivePermissions == 'admin'"
            v-b-tooltip.hover
            class="mdi mdi-delete float-right h5 clickable mr-2"
            aria-hidden="true"
            title="Remove Component"
            @click="showDeleteConfirmation = !showDeleteConfirmation"
          />

          <!-- Duplicate component -->
          <span v-if="effectivePermissions == 'admin'" class="float-right mr-2">
            <NewComponentModal
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
          <span v-if="component.id && effectivePermissions == 'admin'" class="float-right mr-2">
            <template v-if="component.releasable">
              <i
                v-b-tooltip.hover
                class="mdi mdi-stamper h5 clickable"
                aria-hidden="true"
                title="Release Component"
                @click="confirmComponentRelease"
              />
            </template>
            <template v-else>
              <span
                v-b-tooltip.hover
                :title="
                  component.released
                    ? 'Component has already been released'
                    : 'All rules must be locked to release a component'
                "
              >
                <i class="mdi mdi-stamper h5 clickable text-muted" aria-hidden="true" />
              </span>
            </template>
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
import NewComponentModal from "../components/NewComponentModal.vue";

export default {
  name: "ComponentCard",
  components: {
    NewComponentModal,
  },
  mixins: [AlertMixinVue, FormMixinVue],
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
  methods: {
    confirmComponentRelease: function () {
      let body = this.$createElement("div", {
        domProps: {
          innerHTML:
            "<p>Are you sure you want to release this component?</p><p>This cannot be undone and will make the component publicly available within Vulcan.</p>",
        },
      });
      this.$bvModal
        .msgBoxConfirm(body, {
          title: "Release Component",
          size: "md",
          okTitle: "Release Component",
          cancelTitle: "Cancel",
          hideHeaderClose: false,
          centered: true,
        })
        .then((value) => {
          // confirm value was either null or false (clicked away or clicked cancel)
          if (!value) {
            return;
          }

          let payload = {
            component: {
              released: true,
            },
          };
          axios
            .patch(`/components/${this.component.id}`, payload)
            .then((response) => {
              this.alertOrNotifyResponse(response);
              this.$emit("projectUpdated");
            })
            .catch(this.alertOrNotifyResponse);
        })
        .catch((err) => {});
    },
  },
};
</script>

<style scoped></style>
