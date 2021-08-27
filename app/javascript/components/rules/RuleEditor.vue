<template>
  <div>
    <p v-if="rule.locked" class="text-danger">
      This control is locked and must first be unlocked if changes or deletion are required.
    </p>
    <b-form>
      <RuleForm
        :rule="rule"
        :statuses="statuses"
        :severities="severities"
        :disabled="rule.locked"
      />

      <!-- rule_descriptions -->
      <!-- This is currently commented out to avoid confusion with DISA description schema -->
      <!-- <template v-if="rule.status == 'Applicable - Configurable'">
        <div @click="showRuleDescriptions = !showRuleDescriptions" class="clickable mb-2">
          <h2 class="m-0 d-inline-block">Rule Descriptions</h2>
          <b-badge pill class="superVerticalAlign">{{rule.rule_descriptions_attributes.length}}</b-badge>

          <i class="mdi mdi-menu-down superVerticalAlign collapsableArrow" v-if="showRuleDescriptions"></i>
          <i class="mdi mdi-menu-up superVerticalAlign collapsableArrow" v-if="!showRuleDescriptions"></i>
        </div>
        <b-collapse v-model="showRuleDescriptions">
          <RuleDescriptionForm
            :key="'rule_description_' + index"
            v-for="(description, index) in rule.rule_descriptions_attributes"
            :rule="rule"
            :index="index"
            :description="description"
            :disabled="rule.locked"
          />
          <b-button class="mb-2" @click="addRuleDescription" v-if="rule.locked == false"><i class="mdi mdi-plus"></i>Add Description</b-button>
        </b-collapse>
      </template> -->

      <!-- disa_rule_description -->
      <template v-if="rule.status == 'Applicable - Configurable'">
        <div class="clickable mb-2" @click="showDisaRuleDescriptions = !showDisaRuleDescriptions">
          <h2 class="m-0 d-inline-block">Rule Description</h2>
          <!-- <b-badge pill class="superVerticalAlign">{{rule.disa_rule_descriptions_attributes.length}}</b-badge> -->

          <i
            v-if="showDisaRuleDescriptions"
            class="mdi mdi-menu-down superVerticalAlign collapsableArrow"
          />
          <i
            v-if="!showDisaRuleDescriptions"
            class="mdi mdi-menu-up superVerticalAlign collapsableArrow"
          />
        </div>
        <b-collapse v-model="showDisaRuleDescriptions">
          <DisaRuleDescriptionForm
            v-for="(description, index) in rule.disa_rule_descriptions_attributes"
            :key="'disa_rule_description_' + index"
            :rule="rule"
            :index="index"
            :description="description"
            :disabled="rule.locked"
          />
          <!-- This is commented out because there is currently the assumption that users will only need one description -->
          <!-- <b-button class="mb-2" @click="addDisaRuleDescription" v-if="rule.locked == false"><i class="mdi mdi-plus"></i>Add DISA Description</b-button> -->
        </b-collapse>
      </template>

      <!-- checks -->
      <template v-if="rule.status == 'Applicable - Configurable'">
        <div class="clickable mb-2" @click="showChecks = !showChecks">
          <h2 class="m-0 d-inline-block">Checks</h2>
          <b-badge pill class="superVerticalAlign">{{ rule.checks_attributes.length }}</b-badge>

          <i v-if="showChecks" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
          <i v-if="!showChecks" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
        </div>
        <b-collapse v-model="showChecks">
          <CheckForm
            v-for="(check, index) in rule.checks_attributes"
            :key="'checks_' + index"
            :rule="rule"
            :index="index"
            :check="check"
            :disabled="rule.locked"
          />
          <b-button v-if="rule.locked == false" class="mb-2" @click="addCheck"
            ><i class="mdi mdi-plus" />Add Check</b-button
          >
        </b-collapse>
      </template>
    </b-form>
  </div>
</template>

<script>
import RuleForm from "./forms/RuleForm.vue";
import CheckForm from "./forms/CheckForm.vue";
import DisaRuleDescriptionForm from "./forms/DisaRuleDescriptionForm.vue";

export default {
  name: "RuleEditor",
  components: { RuleForm, CheckForm, DisaRuleDescriptionForm },
  props: {
    rule: {
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
  },
  data: function () {
    return {
      showChecks: false,
      showDisaRuleDescriptions: false,
      showRuleDescriptions: false,
    };
  },
};
</script>

<style scoped></style>
