<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />
    <b-row class="align-items-center">
      <b-col md="8">
        <h1>
          {{ component.name }}
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
              Advanced Fields Enabled
            </b-form-checkbox>

            <div class="m-3" />

            <RulesReadOnlyView
              :effective-permissions="effective_permissions"
              :current-user-id="current_user_id"
              :component="component"
              :rules="rules"
              :statuses="statuses"
              :severities="severities"
              :severities_map="severities_map"
              :component-selected-rule-id="componentSelectedRuleId"
              @ruleSelected="updateSelectedRule"
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
      <b-col v-if="effective_permissions" md="3">
        <b-row class="pb-2">
          <b-col>
            <div class="clickable" @click="showDetails = !showDetails">
              <h5 class="m-0 d-inline-block">Component Details</h5>
              <i v-if="showDetails" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
              <i v-if="!showDetails" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
            </div>
            <b-collapse id="collapse-metadata" v-model="showDetails">
              <div v-if="component.name">
                <p v-linkified class="ml-2 mb-0 mt-2">
                  <strong>Name: </strong>{{ component.name }}
                </p>
              </div>
              <div v-if="component.version">
                <p v-linkified class="ml-2 mb-0 mt-2">
                  <strong>Version: </strong>{{ component.version }}
                </p>
              </div>
              <div v-if="component.release">
                <p v-linkified class="ml-2 mb-0 mt-2">
                  <strong>Release: </strong>{{ component.release }}
                </p>
              </div>
              <div v-if="component.title">
                <p v-linkified class="ml-2 mb-0 mt-2">
                  <strong>Title: </strong>{{ component.title }}
                </p>
              </div>
              <div v-if="component.description">
                <p v-linkified class="ml-2 mb-0 mt-2">
                  <strong>Description: </strong>{{ component.description }}
                </p>
              </div>
              <UpdateComponentDetailsModal
                :component="component"
                @componentUpdated="refreshComponent"
              />
            </b-collapse>
          </b-col>
        </b-row>
        <b-row class="pb-2">
          <b-col>
            <div class="clickable" @click="showMetadata = !showMetadata">
              <h5 class="m-0 d-inline-block">Component Metadata</h5>
              <i
                v-if="showMetadata"
                class="mdi mdi-menu-down superVerticalAlign collapsableArrow"
              />
              <i v-if="!showMetadata" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
            </div>
            <b-collapse id="collapse-metadata" v-model="showMetadata">
              <div v-for="(value, propertyName) in component.metadata" :key="propertyName">
                <p v-linkified class="ml-2 mb-0 mt-2">
                  <strong>{{ propertyName }}: </strong>{{ value }}
                </p>
              </div>
              <UpdateMetadataModal :component="component" @componentUpdated="refreshComponent" />
            </b-collapse>
          </b-col>
        </b-row>
        <b-row class="pb-2">
          <b-col>
            <div class="clickable" @click="showHistory = !showHistory">
              <h5 class="m-0 d-inline-block">Component History</h5>
              <i v-if="showHistory" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
              <i v-if="!showHistory" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
            </div>
            <b-collapse id="collapse-metadata" v-model="showHistory">
              <History
                :histories="component.histories"
                :revertable="false"
                abbreviate-type="BaseRule"
              />
            </b-collapse>
          </b-col>
        </b-row>
        <b-row class="pb-2">
          <b-col>
            <div class="clickable" @click="showAdditionalQuestions = !showAdditionalQuestions">
              <h5 class="m-0 d-inline-block">Component Additional Questions</h5>
              <i
                v-if="showAdditionalQuestions"
                class="mdi mdi-menu-down superVerticalAlign collapsableArrow"
              />
              <i
                v-if="!showAdditionalQuestions"
                class="mdi mdi-menu-up superVerticalAlign collapsableArrow"
              />
            </div>
            <b-collapse id="collapse-metadata" v-model="showAdditionalQuestions">
              <div
                v-for="value in component.additional_questions"
                :key="value.id + value.question_type + value.name"
              >
                <p v-linkified class="ml-2 mb-0 mt-2">
                  <strong>{{ value.name }}: </strong>
                  <template v-if="value.question_type === 'dropdown'">
                    Options: {{ value.options.join(", ") }}
                  </template>
                  <template v-else> Freeform Text </template>
                </p>
              </div>
              <AddQuestionsModal :component="component" @componentUpdated="refreshComponent" />
            </b-collapse>
          </b-col>
        </b-row>
        <b-row class="pb-2">
          <b-col>
            <div class="clickable" @click="showReviews = !showReviews">
              <h5 class="m-0 d-inline-block">Component Reviews</h5>
              <i v-if="showReviews" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
              <i v-if="!showReviews" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
            </div>
            <b-collapse id="collapse-metadata" v-model="showReviews">
              <div v-for="review in component.reviews" :key="review.id">
                <p class="ml-2 mb-0 mt-2">
                  <strong>
                    {{ review.displayed_rule_name }}
                  </strong>
                </p>
                <p class="ml-2 mb-0 mt-0">
                  <strong>{{ review.name }} - {{ actionDescriptions[review.action] }}</strong>
                </p>
                <p class="ml-2 mb-0">
                  <small>{{ friendlyDateTime(review.created_at) }}</small>
                </p>
                <p class="ml-3 mb-3 white-space-pre-wrap">{{ review.comment }}</p>
              </div>
            </b-collapse>
          </b-col>
        </b-row>
        <hr />
        <b-row>
          <b-col>
            <div v-if="selectedRule.reviews">
              <RuleReviews :rule="selectedRule" />
              <br />
            </div>
            <div v-if="selectedRule.histories">
              <RuleHistories
                :rule="selectedRule"
                :component="component"
                :statuses="statuses"
                :severities="severities"
              />
              <br />
            </div>
            <RuleSatisfactions
              :component="component"
              :rule="selectedRule"
              :selected-rule-id="selectedRule.id"
              :project-prefix="component.prefix"
              :read-only="true"
              @ruleSelected="handleRuleSelected($event)"
            />
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
import SortRulesMixin from "../../mixins/SortRulesMixin.vue";
import ConfirmComponentReleaseMixin from "../../mixins/ConfirmComponentReleaseMixin.vue";
import History from "../shared/History.vue";
import RulesReadOnlyView from "../rules/RulesReadOnlyView.vue";
import RuleReviews from "../rules/RuleReviews.vue";
import RuleHistories from "../rules/RuleHistories.vue";
import RuleSatisfactions from "../rules/RuleSatisfactions.vue";
import MembershipsTable from "../memberships/MembershipsTable.vue";
import UpdateComponentDetailsModal from "./UpdateComponentDetailsModal.vue";
import UpdateMetadataModal from "./UpdateMetadataModal.vue";
import AddQuestionsModal from "./AddQuestionsModal.vue";

export default {
  name: "Projectcomponent",
  components: {
    History,
    RulesReadOnlyView,
    MembershipsTable,
    UpdateComponentDetailsModal,
    UpdateMetadataModal,
    AddQuestionsModal,
    RuleReviews,
    RuleHistories,
    RuleSatisfactions,
  },
  mixins: [
    DateFormatMixinVue,
    AlertMixinVue,
    FormMixinVue,
    RoleComparisonMixin,
    ConfirmComponentReleaseMixin,
    SortRulesMixin,
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
    severities_map: {
      type: Object,
      required: true,
    },
    available_roles: {
      type: Array,
      required: true,
    },
  },
  data: function () {
    return {
      selectedRule: {},
      showDetails: true,
      showMetadata: true,
      showHistory: true,
      showAdditionalQuestions: true,
      showReviews: true,
      component: this.initialComponentState,
      componentTabIndex: 0,
      componentSelectedRuleId: null,
      actionDescriptions: {
        comment: "Commented",
        request_review: "Requested Review",
        revoke_review_request: "Revoked Request for Review",
        request_changes: "Requested Changes",
        approve: "Approved",
        lock_control: "Locked",
        unlock_control: "Unlocked",
      },
    };
  },
  computed: {
    rules: function () {
      return [...this.component.rules].sort(this.compareRules);
    },
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
          text: this.component.name,
          active: true,
        },
      ];
    },
    tabsColumns: function () {
      if (this.effective_permissions) {
        return "9";
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
        location.reload();
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
    updateSelectedRule: function (rule) {
      axios
        .get(`/rules/${rule.id}`)
        .then((response) => {
          this.selectedRule = response.data;
        })
        .catch(this.alertOrNotifyResponse);
    },
    handleRuleSelected: function (ruleId) {
      this.componentSelectedRuleId = ruleId;
    },
  },
};
</script>

<style scoped></style>
