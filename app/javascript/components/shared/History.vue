<template>
  <div>
    <div v-for="history in histories" :key="history.id">
      <p class="ml-2 mb-0 mt-2">
        <strong>{{ history.name }}</strong>
      </p>
      <p class="ml-2 mb-0">
        <small>{{ friendlyDateTime(history.created_at) }}</small>
      </p>
      <p v-if="history.comment" class="ml-3 mb-0 white-space-pre-wrap">{{ history.comment }}</p>

      <!-- Associated audits are abbreviated -->
      <template v-if="abbreviateType">
        <p v-if="history.action == 'create'" class="ml-3 mb-0 text-success">
          {{ userIdentifier(history) }} was created
        </p>
        <template v-if="history.action == 'update'">
          <p
            v-if="history.audited_changes.map((c) => c.field).includes('deleted_at')"
            class="ml-3 mb-0 text-danger"
          >
            {{ userIdentifier(history) }} was deleted
          </p>
          <p v-else class="ml-3 mb-0 text-info">{{ userIdentifier(history) }} was updated</p>
        </template>
      </template>
      <template v-else>
        <!-- Edit or Delete action -->
        <template v-if="history.action == 'update' || history.action == 'destroy'">
          <template v-if="revertable">
            <RuleRevertModal
              :rule="rule"
              :component="component"
              :history="history"
              :statuses="statuses"
              :severities="severities"
            />
          </template>
          <template v-else>
            <div v-for="changes in history.audited_changes" :key="changes.id">
              <p v-if="history.action == 'update'" class="ml-3 mb-0 text-info">
                {{ userIdentifier(history) }} {{ computeUpdateText(changes) }}
              </p>
            </div>
            <p v-if="history.action == 'destroy'" class="ml-3 mb-0 text-danger">
              {{ userIdentifier(history) }} was {{ computeDeletionText(history) }}
            </p>
          </template>
        </template>

        <!-- Create action -->
        <p v-if="history.action == 'create'" class="ml-3 mb-0 text-success">
          {{ userIdentifier(history) }} was {{ computeCreationText(history) }}
        </p>
      </template>
    </div>
  </div>
</template>

<script>
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import HumanizedTypesMixInVue from "../../mixins/HumanizedTypesMixIn.vue";
import RuleRevertModal from "./../rules/RuleRevertModal.vue";

export default {
  name: "History",
  components: { RuleRevertModal },
  mixins: [DateFormatMixinVue, HumanizedTypesMixInVue],
  props: {
    histories: {
      type: Array,
      default: () => [],
    },
    rule: {
      type: Object,
      required: false,
    },
    statuses: {
      type: Array,
      required: false,
    },
    severities: {
      type: Array,
      required: false,
    },
    revertable: {
      type: Boolean,
      default: true,
    },
    component: {
      type: Object,
      required: false,
    },
    abbreviateType: {
      type: String,
      required: false,
    },
  },
  methods: {
    userIdentifier: function (history) {
      return (
        this.humanizedType(history.audited_name) ||
        `${this.humanizedType(history.auditable_type)} ${history.auditable_id}`
      );
    },
    computeCreationText: function (history) {
      if (history.auditable_type == "Membership") {
        return `added as a member with ${
          history.audited_changes.find((element) => element["field"] == "role")["new_value"]
        } permissions`;
      } else {
        return "Created";
      }
    },
    computeUpdateText: function (changes, abbreviated) {
      if (changes.field == "admin") {
        return `was ${changes.new_value ? "promoted to" : "demoted from"} admin`;
      } else {
        return `${changes.field} was updated from ${this.prettifyObjects(
          changes.prev_value
        )} to ${this.prettifyObjects(changes.new_value)}`;
      }
    },
    prettifyObjects: function (value) {
      if (typeof value === "object") {
        return JSON.stringify(value, null, 4);
      } else {
        return value;
      }
    },
    computeDeletionText: function (history) {
      if (history.auditable_type == "Membership") {
        return "removed as a member";
      } else {
        return "Deleted";
      }
    },
  },
};
</script>

<style scoped></style>
