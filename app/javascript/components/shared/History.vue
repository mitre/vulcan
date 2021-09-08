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
        <RuleRevertModal
          v-if="revertable"
          :rule="rule"
          :history="history"
          :statuses="statuses"
          :severities="severities"
        />
      </template>

      <!-- Create action -->
      <template v-if="history.action == 'create'">
        <p class="ml-3 mb-0 text-success">
          {{ humanizedType(history.auditable_type) }} was Created.
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
};
</script>

<style scoped></style>
