<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />
    <b-row class="align-items-center">
      <b-col md="8">
        <h1>
          {{ component.version }}
          <i v-if="component.released" class="mdi mdi-stamper" aria-hidden="true" />
        </h1>
      </b-col>
      <b-col md="4" class="text-muted text-md-right">
        <p v-if="lastAudit" class="text-muted mb-1">
          <template v-if="lastAudit.created_at">
            Last update on {{ friendlyDateTime(lastAudit.created_at) }}
          </template>
          <template v-if="lastAudit.user_id"> by {{ lastAudit.user_id }} </template>
        </p>
        <p class="mb-1">
          <span v-if="component.admin_name">
            {{ component.admin_name }}
            {{ component.admin_email ? `(${component.admin_email})` : "" }}
          </span>
          <em v-else>No Component Admin</em>
        </p>
      </b-col>
    </b-row>

    <b-row>
      <b-col :md="tabsColumns" class="border-right">
        <!-- Tab view for project information -->
        <b-tabs v-model="componentTabIndex" content-class="mt-3" justified>
          <!-- Component rules -->
          <b-tab :title="`Controls (${component.rules.length})`">
            <b-button
              v-if="role_gte_to(effective_permissions, 'author')"
              class="m-2"
              variant="primary"
              :href="`/components/${component.id}/controls`"
            >
              Edit Component Controls
            </b-button>
            <span v-b-tooltip.hover :title="releaseComponentTooltip">
              <b-button
                v-if="role_gte_to(effective_permissions, 'admin')"
                class="m-2"
                variant="success"
                :disabled="!component.releasable"
                @click="confirmComponentRelease"
              >
                Release Component
              </b-button>
            </span>

            <b-form-checkbox
              v-if="role_gte_to(effective_permissions, 'admin')"
              v-model="component.advanced_fields"
              name="editor-selector-check-button"
              class="m-2 d-inline-block"
              switch
              @change="toggleAdvancedFields"
            >
              Advanced Fields
            </b-form-checkbox>

            <div class="m-3" />

            <RulesReadOnlyView
              :effective-permissions="effective_permissions"
              :current-user-id="current_user_id"
              :component="component"
              :rules="component.rules"
              :statuses="statuses"
              :severities="severities"
            />
          </b-tab>

          <!-- Members -->
          <b-tab
            v-if="effective_permissions"
            :title="`Members (${
              component.memberships_count + component.inherited_memberships.length
            })`"
          >
            <MembershipsTable
              :editable="role_gte_to(effective_permissions, 'admin')"
              :membership_type="'Component'"
              :membership_id="component.id"
              :memberships="component.memberships"
              :memberships_count="component.memberships_count"
              :available_members="component.available_members"
              :available_roles="available_roles"
            />
            <hr />

            <MembershipsTable
              :editable="false"
              :membership_type="'Component'"
              :membership_id="component.id"
              :memberships="component.inherited_memberships"
              :memberships_count="component.inherited_memberships.length"
              :header_text="'Inherited Members from Project'"
            />
          </b-tab>
        </b-tabs>
      </b-col>
      <b-col v-if="effective_permissions" md="2">
        <b-row>
          <b-col>
            <div class="clickable" @click="showHistory = !showHistory">
              <h5 class="m-0 d-inline-block">Component History</h5>

              <i v-if="showHistory" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
              <i v-if="!showHistory" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
            </div>
            <b-collapse id="collapse-metadata" v-model="showHistory">
              <History :histories="component.histories" :revertable="false" />
            </b-collapse>
          </b-col>
        </b-row>
      </b-col>
    </b-row>
  </div>
</template>

<script>
import _ from "lodash";
import axios from "axios";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import ConfirmComponentReleaseMixin from "../../mixins/ConfirmComponentReleaseMixin.vue";
import History from "../shared/History.vue";
import RulesReadOnlyView from "../rules/RulesReadOnlyView.vue";
import MembershipsTable from "../memberships/MembershipsTable.vue";

export default {
  name: "Projectcomponent",
  components: {
    History,
    RulesReadOnlyView,
    MembershipsTable,
  },
  mixins: [
    DateFormatMixinVue,
    AlertMixinVue,
    FormMixinVue,
    RoleComparisonMixin,
    ConfirmComponentReleaseMixin,
  ],
  props: {
    effective_permissions: {
      type: String,
    },
    initialComponentState: {
      type: Object,
      required: true,
    },
    project: {
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
    severities: {
      type: Array,
      required: true,
    },
    available_roles: {
      type: Array,
      required: true,
    },
  },
  data: function () {
    return {
      showMetadata: true,
      showHistory: true,
      component: this.initialComponentState,
      componentTabIndex: 0,
    };
  },
  computed: {
    lastAudit: function () {
      return this.component.histories?.slice(0, 1)?.pop();
    },
    breadcrumbs: function () {
      return [
        {
          text: "Projects",
          href: "/projects",
        },
        {
          text: this.project.name,
          href: `/projects/${this.project.id}`,
        },
        {
          text: this.component.version,
          active: true,
        },
      ];
    },
    tabsColumns: function () {
      if (this.effective_permissions) {
        return "10";
      }
      return "12";
    },
    releaseComponentTooltip: function () {
      if (this.component.released) {
        return "Component has already been released";
      }

      if (this.component.releasable) {
        return "";
      }

      return "All rules must be locked to release a component";
    },
  },
  watch: {
    componentTabIndex: function (_) {
      localStorage.setItem(
        `componentTabIndex-${this.component.id}`,
        JSON.stringify(this.componentTabIndex)
      );
    },
  },
  mounted: function () {
    // Persist `currentTab` across page loads
    if (localStorage.getItem(`componentTabIndex-${this.component.id}`)) {
      try {
        this.$nextTick(
          () =>
            (this.componentTabIndex = JSON.parse(
              localStorage.getItem(`componentTabIndex-${this.component.id}`)
            ))
        );
      } catch (e) {
        localStorage.removeItem(`componentTabIndex-${this.component.id}`);
      }
    }
  },
  methods: {
    refreshComponent: function () {
      axios.get(`/components/${this.component.id}`).then((response) => {
        this.component = response.data;
      });
    },
    toggleAdvancedFields: function (advanced_fields) {
      if (
        confirm(
          `Are you sure you want to ${advanced_fields ? "enable" : "disable"} advanced fields?`
        )
      ) {
        let payload = {
          component: {
            advanced_fields: advanced_fields,
          },
        };
        axios
          .patch(`/components/${this.component.id}`, payload)
          .then(this.addComponentSuccess)
          .catch(this.alertOrNotifyResponse);
      } else {
        this.component.advanced_fields = !advanced_fields;
      }
    },
  },
};
</script>

<style scoped></style>
