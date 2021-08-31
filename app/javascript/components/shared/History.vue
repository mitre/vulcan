<template>
  <div>
    <div v-for="history in histories" :key="history.id">
      <p class="ml-2 mb-0 mt-2">
        <strong>{{ history.name }}</strong>
      </p>
      <p class="ml-2 mb-0">
        <small>{{ friendlyDateTime(history.created_at) }}</small>
      </p>
      <!-- Edit on the Rule itself -->
      <template v-if="history.auditable_type == 'Rule'">
        <!-- Edit on the rule itself -->
        <template v-if="history.action == 'update'">
          <a v-b-toggle="`history-collapse-${history.id}`" class="ml-3 text-info clickable"
            >{{ friendlyAuditableType(history.auditable_type) }} Updated...</a
          >
          <b-collapse :id="`history-collapse-${history.id}`" class="mt-2">
            <div
              v-for="audited_change in history.audited_changes"
              :key="audited_change.field"
              class="ml-3 mb-3"
            >
              <p class="mb-1">
                <strong>{{ audited_change.field }}</strong> was changed from
                <br />
                <span class="historyChangeText">{{
                  audited_change.prev_value ? audited_change.prev_value : "*no value*"
                }}</span>
                <br />to<br />
                <span class="historyChangeText">{{
                  audited_change.new_value ? audited_change.new_value : "*no value*"
                }}</span>
              </p>
              <RuleRevertModal
                v-if="revertable"
                :rule="rule"
                :history="history"
                :audited_change="audited_change"
                :statuses="statuses"
                :severities="severities"
              />
            </div>
          </b-collapse>
        </template>

        <!-- Create on the rule itself -->
        <template v-if="history.action == 'create'">
          <p class="ml-3 mb-0 text-success">
            {{ friendlyAuditableType(history.auditable_type) }} was created
          </p>
        </template>
      </template>

      <!-- Edit or Deletion on one of the Rule's associated records-->
      <template v-else>
        <!-- Create on the rule associated record -->
        <template v-if="history.action == 'create'">
          <p class="ml-3 mb-0 text-success">
            {{ friendlyAuditableType(history.auditable_type) }} was created
          </p>
        </template>

        <!-- Edit on the associated record -->
        <template v-if="history.action == 'update'">
          <a v-b-toggle="`history-collapse-${history.id}`" class="ml-3 text-info clickable"
            >{{ friendlyAuditableType(history.auditable_type) }} Updated...</a
          >
          <b-collapse :id="`history-collapse-${history.id}`" class="mt-2">
            <div
              v-for="audited_change in history.audited_changes"
              :key="audited_change.field"
              class="ml-3 mb-3"
            >
              <p class="mb-1">
                <strong>{{ audited_change.field }}</strong> was changed from
                <br />
                <span class="historyChangeText">{{
                  audited_change.prev_value ? audited_change.prev_value : "*no value*"
                }}</span>
                <br />to<br />
                <span class="historyChangeText">{{
                  audited_change.new_value ? audited_change.new_value : "*no value*"
                }}</span>
              </p>
              <RuleRevertModal
                v-if="revertable"
                :rule="rule"
                :history="history"
                :audited_change="audited_change"
                :statuses="statuses"
                :severities="severities"
              />
            </div>
          </b-collapse>
        </template>

        <!-- Deletion on the associated record -->
        <template v-if="history.action == 'destroy'">
          <a v-b-toggle="`history-collapse-${history.id}`" class="ml-3 text-danger clickable"
            >{{ friendlyAuditableType(history.auditable_type) }} Deleted...</a
          >
          <b-collapse :id="`history-collapse-${history.id}`" class="mt-2">
            <div
              v-for="audited_change in history.audited_changes"
              :key="audited_change.field"
              class="ml-3 mb-1"
            >
              <p class="mb-1">
                <strong>{{ audited_change.field }}</strong
                >:
                <span class="historyChangeText">{{
                  audited_change.new_value ? audited_change.new_value : "*no value*"
                }}</span>
              </p>
            </div>
            <div class="ml-3 mb-1">
              <RuleRevertModal
                v-if="revertable"
                :rule="rule"
                :history="history"
                :audited_change="null"
                :statuses="statuses"
                :severities="severities"
              />
            </div>
          </b-collapse>
        </template>
      </template>
    </div>
  </div>
</template>

<script>
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import RuleRevertModal from "./../rules/RuleRevertModal.vue";

export default {
  name: "History",
  components: { RuleRevertModal },
  mixins: [DateFormatMixinVue],
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
    friendlyAuditableType: function (type) {
      if (type == "RuleDescription") {
        return "Rule Description";
      } else if (type == "DisaRuleDescription") {
        return "Rule Description";
      }

      return type;
    },
  },
};
</script>

<style scoped></style>
