<script>
import axios from 'axios'
import _ from 'lodash'

import AlertMixinVue from '../../mixins/AlertMixin.vue'
import DateFormatMixinVue from '../../mixins/DateFormatMixin.vue'
import EmptyObjectMixinVue from '../../mixins/EmptyObjectMixin.vue'
import FormMixinVue from '../../mixins/FormMixin.vue'
import HumanizedTypesMixInVue from '../../mixins/HumanizedTypesMixIn.vue'

import CommentModal from '../shared/CommentModal.vue'
import AdditionalQuestions from './forms/AdditionalQuestions'
import CheckForm from './forms/CheckForm'
import DisaRuleDescriptionForm from './forms/DisaRuleDescriptionForm'
import RuleDescriptionForm from './forms/RuleDescriptionForm'
import RuleForm from './forms/RuleForm'

export default {
  name: 'RuleRevertModal',
  components: {
    RuleForm,
    RuleDescriptionForm,
    DisaRuleDescriptionForm,
    CheckForm,
    CommentModal,
    AdditionalQuestions,
  },
  mixins: [
    AlertMixinVue,
    EmptyObjectMixinVue,
    FormMixinVue,
    DateFormatMixinVue,
    HumanizedTypesMixInVue,
  ],
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
    severities: {
      type: Array,
      required: true,
    },
    component: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      selectedRevertRows: [],
      revertFields: ['selected', 'field', 'prev_value', 'new_value'],
    }
  },
  computed: {
    selectedRevertFields() {
      return this.selectedRevertRows.map(audit => audit.field)
    },
    buttonText() {
      if (this.history.action == 'destroy') {
        return `${this.humanizedType(this.history.auditable_type)} was Deleted...`
      }

      if (this.history.action == 'update') {
        return `${this.humanizedType(this.history.auditable_type)} was Updated...`
      }

      return ''
    },
    buttonClass() {
      if (this.history.action == 'destroy') {
        return ['text-danger', 'p-0', 'ml-3']
      }

      return ['text-info', 'p-0', 'ml-3']
    },
    modalId() {
      return `revert-modal-${this.history.id}}`
    },
    currentState() {
      let dependentRecord = {}
      if (this.history.auditable_type == 'Rule') {
        dependentRecord = this.rule
      }
      else if (this.history.auditable_type == 'RuleDescription') {
        dependentRecord = (this.rule.rule_descriptions_attributes || []).find(
          e => e.id == this.history.auditable_id,
        )
      }
      else if (this.history.auditable_type == 'DisaRuleDescription') {
        dependentRecord = (this.rule.disa_rule_descriptions_attributes || []).find(
          e => e.id == this.history.auditable_id,
        )
      }
      else if (this.history.auditable_type == 'Check') {
        dependentRecord = (this.rule.checks_attributes || []).find(
          e => e.id == this.history.auditable_id,
        )
      }
      else if (this.history.auditable_type == 'AdditionalAnswer') {
        dependentRecord.additional_answers_attributes
          = (this.rule.additional_answers_attributes || []).filter(e => e.id == this.history.auditable_id)
      }

      const curState = _.cloneDeep(dependentRecord)
      if (this.isEmpty(curState)) {
        return {}
      }

      // Remove ID to avoid propagating changes by making rule unidentifiable
      delete curState.id
      // Remove _destroy so that form will not be inadvertently hidden
      delete curState._destroy
      return curState
    },
    afterState() {
      // Get `currentState` and duplicate for modification
      const afterState = _.cloneDeep(this.currentState)

      // For each audited_change, check if it is one of the selected properties to revert.
      this.history.audited_changes.forEach((audited_change) => {
        const audited_field = audited_change.field
        if (this.selectedRevertFields.includes(audited_field)) {
          if (this.history.auditable_type === 'AdditionalAnswer') {
            const id = this.rule.additional_answers_attributes.findIndex(
              e => e.id == this.history.auditable_id,
            )
            afterState.additional_answers_attributes[id].answer = audited_change.prev_value
          }
          else {
            afterState[audited_field] = audited_change.prev_value
          }
        }
      })

      return afterState
    },
    // Generate `formFeedback` to be fed to resulting forms to
    // visually display which fields will be changed by a revert.
    formFeedback() {
      const formFeedback = {}
      for (let i = 0; i < this.selectedRevertFields.length; i++) {
        formFeedback[this.selectedRevertFields[i]] = ''
      }
      return formFeedback
    },
  },
  methods: {
    selectAllRows() {
      this.$refs.selectableRevertTable.selectAllRows()
    },
    clearSelectedRows() {
      this.$refs.selectableRevertTable.clearSelected()
    },
    onRowSelected(items) {
      this.selectedRevertRows = items
    },
    showModal() {
      this.$refs.revertModal.show()
    },
    revertHistory(comment) {
      const payload = {
        audit_id: this.history.id,
        fields: this.selectedRevertFields,
        audit_comment: comment,
      }
      axios
        .post(`/rules/${this.rule.id}/revert`, payload)
        .then(this.revertSuccess)
        .catch(this.alertOrNotifyResponse)
    },
    revertSuccess(response) {
      this.alertOrNotifyResponse(response)
      this.$root.$emit('refresh:rule', this.rule.id, 'all')
    },
  },
}
</script>

<template>
  <div>
    <CommentModal
      title="Revert Rule History"
      message="Provide a reason for reverting this change."
      :require-non-empty="true"
      :button-text="buttonText"
      size="xl"
      button-variant="link"
      :button-class="buttonClass"
      @comment="revertHistory($event)"
    >
      <!-- History Metadata -->
      <p class="mb-0">
        <strong>{{ history.name }}</strong>
      </p>
      <p class="mb-0">
        <small>{{ friendlyDateTime(history.created_at) }}</small>
      </p>
      <p class="ml-3 mb-3">
        {{ history.comment || "No change comment was provided." }}
      </p>

      <!-- Selection of fields to revert -->
      <template v-if="history.action == 'update'">
        <p class="h3">
          Select Changes to Revert
        </p>
        <div>
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
              <i
                v-b-tooltip.hover.html
                class="bi bi-info-circle"
                aria-hidden="true"
                title="This is the state of the record before the author made the change.<br>When a row is selected, the record will revert to this value."
              />
            </template>

            <!-- Custom Header for new_value -->
            <template #head(new_value)="">
              Changed To
              <i
                v-b-tooltip.hover.html
                class="bi bi-info-circle"
                aria-hidden="true"
                title="This is the state of the record after the author made the change."
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

          <b-button size="sm" @click="selectAllRows">
            Select all
          </b-button>
          <b-button size="sm" @click="clearSelectedRows">
            Clear selected
          </b-button>
        </div>
      </template>

      <hr>

      <div class="row">
        <!-- CURRENT STATE -->
        <div class="col-6">
          <p class="h3">
            State Before Revert
          </p>

          <template v-if="history.action == 'destroy'">
            <p>No Current State - Deleted</p>
          </template>

          <template v-else-if="history.auditable_type == 'Rule'">
            <RuleForm
              :rule="currentState"
              :statuses="statuses"
              :severities="severities"
              :disabled="true"
              :invalid-feedback="formFeedback"
            />
          </template>

          <template v-else-if="history.auditable_type == 'RuleDescription'">
            <RuleDescriptionForm
              v-if="!isEmpty(currentState)"
              :description="currentState"
              :disabled="true"
              :invalid-feedback="formFeedback"
            />
            <p v-else>
              Description does not exist.
            </p>
          </template>

          <template v-else-if="history.auditable_type == 'DisaRuleDescription'">
            <DisaRuleDescriptionForm
              v-if="!isEmpty(currentState)"
              :description="currentState"
              :disabled="true"
              :invalid-feedback="formFeedback"
            />
            <p v-else>
              Description does not exist.
            </p>
          </template>

          <template v-else-if="history.auditable_type == 'Check'">
            <CheckForm
              v-if="!isEmpty(currentState)"
              :check="currentState"
              :disabled="true"
              :invalid-feedback="formFeedback"
            />
            <p v-else>
              Check does not exist.
            </p>
          </template>

          <template v-else-if="history.auditable_type == 'AdditionalAnswer'">
            <AdditionalQuestions
              :disabled="true"
              :rule="currentState"
              :additional_questions="component.additional_questions"
              :invalid-feedback="formFeedback"
            />
          </template>
        </div>

        <!-- STATE AFTER REVERT -->
        <div class="col-6">
          <p class="h3">
            State After Revert
          </p>

          <p v-if="!afterState || isEmpty(afterState)">
            Could not determine resulting state.
          </p>

          <RuleForm
            v-else-if="history.auditable_type == 'Rule'"
            :rule="afterState"
            :statuses="statuses"
            :severities="severities"
            :disabled="true"
            :valid-feedback="formFeedback"
          />

          <RuleDescriptionForm
            v-else-if="history.auditable_type == 'RuleDescription'"
            :description="afterState"
            :disabled="true"
            :valid-feedback="formFeedback"
          />

          <DisaRuleDescriptionForm
            v-else-if="history.auditable_type == 'DisaRuleDescription'"
            :description="afterState"
            :disabled="true"
            :valid-feedback="formFeedback"
          />

          <CheckForm
            v-else-if="history.auditable_type == 'Check'"
            :check="afterState"
            :disabled="true"
            :valid-feedback="formFeedback"
          />

          <AdditionalQuestions
            v-else-if="history.auditable_type == 'AdditionalAnswer'"
            :disabled="true"
            :rule="afterState"
            :additional_questions="component.additional_questions"
            :valid-feedback="formFeedback"
          />

          <p v-else>
            Could not determine resulting state.
          </p>
        </div>
      </div>
      <hr>
    </CommentModal>
  </div>
</template>

<style scoped></style>
