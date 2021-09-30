<template>
  <div>
    <div v-for="history in histories" :key="history.id">
      <p class="ml-2 mb-0 mt-2">
        <strong>{{ history.name }}</strong>
      </p>
      <p class="ml-2 mb-0">
        <small>{{ friendlyDateTime(history.created_at) }}</small>
      </p>
      <p v-if="history.comment" class="ml-3 mb-0">{{ history.comment }}</p>

      <!-- Edit or Delete action -->
      <template v-if="history.action == 'update' || history.action == 'destroy'">
        <template v-if="revertable">
          <RuleRevertModal
            :rule="rule"
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
        {{ humanizedType(history.auditable_type) }} was Created
      </p>
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
      required: true,
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
  },
  methods: {
    userIdentifier: function (history) {
      return history.audited_name || `${history.auditable_type} ${history.auditable_id}`;
    },
    computeUpdateText: function (changes) {
      if (changes.field == "admin") {
        return `was ${changes.new_value ? "promoted to" : "demoted from"} admin`;
      } else {
        return `${changes.field} was updated from ${changes.prev_value} to ${changes.new_value}`;
      }
    },
    computeDeletionText: function (history) {
      if (history.auditable_type == "ProjectMember") {
        return "removed from the project";
      } else {
        return "Deleted";
      }
    },
  },
};
</script>

<style scoped></style>
