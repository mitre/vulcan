<template>
  <div>
    <!-- Phase 1: Button to open Change Details modal -->
    <b-button variant="link" :class="buttonClass" @click="showDetailsModal = true">
      {{ buttonText }}
    </b-button>

    <!-- Change Details Modal (Phase 1) -->
    <b-modal
      v-model="showDetailsModal"
      :title="'Change Details'"
      size="xl"
      centered
      @hidden="onDetailsHidden"
    >
      <!-- History Metadata -->
      <p class="mb-0">
        <strong>{{ history.name }}</strong>
      </p>
      <p class="mb-0">
        <small>{{ friendlyDateTime(history.created_at) }}</small>
      </p>
      <p class="ml-3 mb-3">{{ history.comment || "No change comment was provided." }}</p>

      <!-- Changes table (read-only) -->
      <template v-if="history.action == 'update'">
        <p class="h5">Fields Changed</p>
        <b-table
          ref="selectableRevertTable"
          :items="history.audited_changes"
          :fields="revertFields"
          select-mode="multi"
          responsive="sm"
          selectable
          @row-selected="onRowSelected"
        >
          <!-- Custom Header for prev_value -->
          <template #head(prev_value)="">
            Changed From
            <b-icon
              v-b-tooltip.hover.html="
                'This is the state of the record before the author made the change.<br>When a row is selected, the record will revert to this value.'
              "
              icon="info-circle"
              aria-hidden="true"
            />
          </template>

          <!-- Custom Header for new_value -->
          <template #head(new_value)="">
            Changed To
            <b-icon
              v-b-tooltip.hover.html="
                'This is the state of the record after the author made the change.'
              "
              icon="info-circle"
              aria-hidden="true"
            />
          </template>

          <!-- Selected Column -->
          <template #cell(selected)="{ rowSelected }">
            <template v-if="rowSelected">
              <span aria-hidden="true">&check;</span>
              <span class="sr-only">Selected</span>
            </template>
            <template v-else>
              <span aria-hidden="true">&nbsp;</span>
              <span class="sr-only">Not selected</span>
            </template>
          </template>

          <!-- Field Column -->
          <template #cell(field)="data">
            {{ humanizedType(data.item.field) }}
          </template>
        </b-table>

        <b-button size="sm" @click="selectAllRows">Select all</b-button>
        <b-button size="sm" @click="clearSelectedRows">Clear selected</b-button>
      </template>

      <!-- Revert confirmation section -->
      <template v-if="showRevertConfirm">
        <hr />
        <div class="mt-3">
          <label for="revert-comment" class="font-weight-bold">Reason for reverting:</label>
          <b-form-textarea
            id="revert-comment"
            v-model="revertComment"
            placeholder="Provide a reason for reverting this change..."
            rows="2"
          />
        </div>
      </template>

      <template #modal-footer>
        <b-button variant="secondary" @click="showDetailsModal = false">Close</b-button>
        <template v-if="!showRevertConfirm">
          <b-button
            variant="warning"
            :disabled="selectedRevertRows.length === 0"
            @click="showRevertConfirm = true"
          >
            Revert Selected Changes...
          </b-button>
        </template>
        <template v-else>
          <b-button variant="secondary" @click="showRevertConfirm = false">Back</b-button>
          <b-button
            variant="danger"
            :disabled="!revertComment || revertComment.trim().length === 0"
            @click="revertHistory(revertComment)"
          >
            Confirm Revert
          </b-button>
        </template>
      </template>
    </b-modal>
  </div>
</template>

<script>
import axios from "axios";

import AlertMixinVue from "../../mixins/AlertMixin.vue";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import HumanizedTypesMixInVue from "../../mixins/HumanizedTypesMixIn.vue";
import { MESSAGE_LABELS } from "../../constants/terminology";

export default {
  name: "RuleRevertModal",
  mixins: [AlertMixinVue, DateFormatMixinVue, HumanizedTypesMixInVue],
  props: {
    rule: {
      type: Object,
      required: true,
    },
    history: {
      type: Object,
      required: true,
    },
    statuses: {
      type: Array,
      required: true,
    },
    component: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return {
      msg: MESSAGE_LABELS,
      showDetailsModal: false,
      showRevertConfirm: false,
      revertComment: "",
      selectedRevertRows: [],
      revertFields: ["selected", "field", "prev_value", "new_value"],
    };
  },
  computed: {
    selectedRevertFields: function () {
      return this.selectedRevertRows.map((audit) => audit.field);
    },
    buttonText: function () {
      if (this.history.action == "destroy") {
        return `${this.humanizedType(this.history.auditable_type)} was Deleted...`;
      }

      if (this.history.action == "update") {
        return `${this.humanizedType(this.history.auditable_type)} was Updated...`;
      }

      return "";
    },
    buttonClass: function () {
      if (this.history.action == "destroy") {
        return ["text-danger", "p-0", "ml-3"];
      }

      return ["text-info", "p-0", "ml-3"];
    },
    modalId: function () {
      return `revert-modal-${this.history.id}}`;
    },
  },
  methods: {
    selectAllRows: function () {
      this.$refs.selectableRevertTable.selectAllRows();
    },
    clearSelectedRows() {
      this.$refs.selectableRevertTable.clearSelected();
    },
    onRowSelected(items) {
      this.selectedRevertRows = items;
    },
    onDetailsHidden() {
      this.showRevertConfirm = false;
      this.revertComment = "";
      this.selectedRevertRows = [];
    },
    revertHistory: function (comment) {
      let payload = {
        audit_id: this.history.id,
        fields: this.selectedRevertFields,
        audit_comment: comment,
      };
      axios
        .post(`/rules/${this.rule.id}/revert`, payload)
        .then(this.revertSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    revertSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.showDetailsModal = false;
      this.$root.$emit("refresh:rule", this.rule.id, "all");
    },
  },
};
</script>

<style scoped></style>
