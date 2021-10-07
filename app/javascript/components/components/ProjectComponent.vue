<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />
    <b-row class="align-items-center">
      <b-col md="8">
        <h1>{{ component.version }}</h1>
      </b-col>
      <b-col md="4" class="text-muted text-md-right">
        <div v-if="lastAudit" class="text-muted">
          <template v-if="lastAudit.created_at">
            Last update on {{ friendlyDateTime(lastAudit.created_at) }}
          </template>
          <template v-if="lastAudit.user_id"> by {{ lastAudit.user_id }} </template>
        </div>
      </b-col>
    </b-row>

    <b-row>
      <b-col md="10" class="border-right">
        <!-- Tab view for project information -->
        <b-tabs v-model="componentTabIndex" content-class="mt-3" justified>
          <!-- Component rules -->
          <b-tab :title="`Controls (${component.rules.length})`">
            <b-button
              v-if="project_permissions"
              class="m-2"
              variant="primary"
              :href="`/components/${component.id}/controls`"
            >
              Edit Component Controls
            </b-button>

            <RulesReadOnlyView
              :project-permissions="project_permissions"
              :current-user-id="current_user_id"
              :component="component"
              :rules="component.rules"
              :statuses="statuses"
              :severities="severities"
            />
          </b-tab>
        </b-tabs>
      </b-col>
      <b-col md="2">
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
import History from "../shared/History.vue";
import RulesReadOnlyView from "../rules/RulesReadOnlyView.vue";

export default {
  name: "Projectcomponent",
  components: {
    History,
    RulesReadOnlyView,
  },
  mixins: [DateFormatMixinVue, AlertMixinVue, FormMixinVue],
  props: {
    project_permissions: {
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
      return this.component.histories.slice(0, 1).pop();
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
      axios.get(`/components/${this.components.id}`).then((response) => {
        this.components = response.data;
      });
    },
  },
};
</script>

<style scoped></style>
