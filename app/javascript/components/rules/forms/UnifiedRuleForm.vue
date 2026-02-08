<template>
  <div>
    <b-form>
      <RuleForm
        :rule="rule"
        :statuses="statuses"
        :disabled="isFormDisabled"
        :fields="ruleFormFields"
        :disa_fields="(!advancedMode || !showCollapsibleSections) && showDisaSection ? disaDescriptionFields : undefined"
        :check_fields="(!advancedMode || !showCollapsibleSections) && showChecksSection ? checkFormFields : undefined"
        :force_enable_additional_questions="forceEnableAdditionalQuestions"
        :additional_questions="additional_questions"
      />

      <!-- Collapsible DISA Rule Description section (advanced mode with extra fields) -->
      <template v-if="advancedMode && showCollapsibleSections && showDisaSection">
        <div class="clickable mb-2" @click="showDisaRuleDescriptions = !showDisaRuleDescriptions">
          <h2 class="m-0 d-inline-block">Rule Description</h2>
          <b-icon v-if="showDisaRuleDescriptions" icon="chevron-down" />
          <b-icon v-if="!showDisaRuleDescriptions" icon="chevron-up" />
        </div>
        <b-collapse v-model="showDisaRuleDescriptions">
          <div
            v-for="(description, index) in rule.disa_rule_descriptions_attributes"
            :key="'disa_rule_description_' + index"
          >
            <div v-if="description._destroy != true" class="card p-3 mb-3">
              <p>
                <strong>{{ description.id == null ? "New " : "" }}Rule Description</strong>
              </p>
              <DisaRuleDescriptionForm
                :rule="rule"
                :index="index"
                :description="description"
                :disabled="isFormDisabled"
                :fields="disaDescriptionFields"
              />
            </div>
          </div>
        </b-collapse>
      </template>

      <!-- Collapsible Checks section (advanced mode with extra fields) -->
      <template v-if="advancedMode && showCollapsibleSections && showChecksSection">
        <div class="clickable mb-2" @click="showChecks = !showChecks">
          <h2 class="m-0 d-inline-block">Checks</h2>
          <b-badge pill class="superVerticalAlign">{{
            rule.checks_attributes.filter((e) => e._destroy != true).length
          }}</b-badge>
          <b-icon v-if="showChecks" icon="chevron-down" />
          <b-icon v-if="!showChecks" icon="chevron-up" />
        </div>
        <b-collapse v-model="showChecks">
          <div v-for="(check, index) in rule.checks_attributes" :key="'checks_' + index">
            <div v-if="check._destroy != true" class="card p-3 mb-3">
              <p>
                <strong>{{ check.id == null ? "New " : "" }}Check</strong>
              </p>
              <CheckForm :rule="rule" :index="index" :check="check" :disabled="isFormDisabled" />
              <a
                v-if="!isFormDisabled"
                class="clickable text-dark"
                @click="$root.$emit('update:check', rule, { ...check, _destroy: true }, index)"
              >
                <b-icon icon="trash" aria-hidden="true" />
                Remove Check
              </a>
            </div>
          </div>
          <b-button v-if="!isFormDisabled" class="mb-2" @click="$root.$emit('add:check', rule)">
            <b-icon icon="plus" />Add Check
          </b-button>
        </b-collapse>
      </template>
    </b-form>

    <RuleSecurityRequirementsGuideInformation
      :nist_control_family="rule.nist_control_family"
      :srg_rule="rule.srg_rule_attributes"
      :cci="rule.ident"
      :srg_info="rule.srg_info"
    />

    <!-- Status hint -->
    <div v-if="effectiveStatus !== 'Applicable - Configurable'">
      <hr />
      <p>
        <small>Some fields are hidden due to the control's status.</small>
      </p>
    </div>
  </div>
</template>

<script>
import { computed } from "vue";
import RuleForm from "./RuleForm.vue";
import CheckForm from "./CheckForm.vue";
import DisaRuleDescriptionForm from "./DisaRuleDescriptionForm.vue";
import RuleSecurityRequirementsGuideInformation from "../RuleSecurityRequirementsGuideInformation.vue";
import { useRuleFormFields } from "../../../composables/useRuleFormFields";

export default {
  name: "UnifiedRuleForm",
  components: {
    RuleForm,
    CheckForm,
    DisaRuleDescriptionForm,
    RuleSecurityRequirementsGuideInformation,
  },
  props: {
    rule: {
      type: Object,
      required: true,
    },
    statuses: {
      type: Array,
      required: true,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
    advancedMode: {
      type: Boolean,
      default: false,
    },
    additional_questions: {
      type: Array,
      default: () => [],
    },
  },
  setup(props) {
    // Use computed refs (not toRef) for Vue 2.7 reactivity safety
    const ruleRef = computed(() => props.rule);
    const advancedRef = computed(() => props.advancedMode);
    const readOnlyRef = computed(() => props.readOnly);

    const composable = useRuleFormFields(ruleRef, advancedRef, { readOnly: readOnlyRef });

    return {
      ...composable,
    };
  },
  data() {
    return {
      showChecks: false,
      showDisaRuleDescriptions: false,
    };
  },
};
</script>

<style scoped></style>
