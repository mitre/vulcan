<template>
  <div>
    <b-form>
      <RuleForm
        :rule="rule"
        :statuses="statuses"
        :severities="severities"
        :disabled="disabledForm"
      />

      <!-- rule_descriptions -->
      <!-- This is currently commented out to avoid confusion with DISA description schema -->
      <!-- <template v-if="rule.status == 'Applicable - Configurable'">
        <div @click="showRuleDescriptions = !showRuleDescriptions" class="clickable mb-2">
          <h2 class="m-0 d-inline-block">Rule Descriptions</h2>
          <b-badge pill class="superVerticalAlign">{{rule.rule_descriptions_attributes.filter((e) => e._destroy != true ).length}}</b-badge>

          <i class="mdi mdi-menu-down superVerticalAlign collapsableArrow" v-if="showRuleDescriptions"></i>
          <i class="mdi mdi-menu-up superVerticalAlign collapsableArrow" v-if="!showRuleDescriptions"></i>
        </div>
        <b-collapse v-model="showRuleDescriptions">
          <div v-for="(description, index) in rule.rule_descriptions_attributes" :key="'rule_description_' + index">
            <div v-if="description._destroy != true" class="card p-3 mb-3">
              <p>
                <strong>{{ description.id == null ? "New " : "" }}Rule Description</strong>
              </p>
              <RuleDescriptionForm
                :rule="rule"
                :index="index"
                :description="description"
                :disabled="disabledForm"
              />

              <a
                v-if="!disabledForm"
                class="clickable text-dark"
                @click="$root.$emit('update:description', rule, { ...description, _destroy: true }, index)"
              >
                <i class="mdi mdi-trash-can" aria-hidden="true" />
                Remove Rule Description
              </a>
            </div>
          </div>

          <b-button class="mb-2" @click="$root.$emit('add:description', rule)" v-if="!disabledForm"><i class="mdi mdi-plus"></i>Add Description</b-button>
        </b-collapse>
      </template> -->

      <!-- disa_rule_description -->
      <template v-if="rule.status == 'Applicable - Configurable'">
        <div class="clickable mb-2" @click="showDisaRuleDescriptions = !showDisaRuleDescriptions">
          <h2 class="m-0 d-inline-block">Rule Description</h2>
          <!-- <b-badge pill class="superVerticalAlign">{{rule.disa_rule_descriptions_attributes.filter((e) => e._destroy != true ).length}}</b-badge> -->

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
                :disabled="disabledForm"
              />
              <!-- This is commented out because there is currently the assumption that users will only need one description -->
              <!-- <a
                v-if="!disabledForm"
                class="clickable text-dark"
                @click="
                  $root.$emit('update:disaDescription', rule, { ...description, _destroy: true }, index)
                "
              >
                <i class="mdi mdi-trash-can" aria-hidden="true"></i>
                Remove DISA Description
              </a> -->
            </div>
          </div>

          <!-- This is commented out because there is currently the assumption that users will only need one description -->
          <!-- <b-button class="mb-2" @click="$root.$emit('add:disaDescription', rule)" v-if="disabledForm"><i class="mdi mdi-plus"></i>Add DISA Description</b-button> -->
        </b-collapse>
      </template>

      <!-- checks -->
      <template v-if="rule.status == 'Applicable - Configurable'">
        <div class="clickable mb-2" @click="showChecks = !showChecks">
          <h2 class="m-0 d-inline-block">Checks</h2>
          <b-badge pill class="superVerticalAlign">{{
            rule.checks_attributes.filter((e) => e._destroy != true).length
          }}</b-badge>

          <i v-if="showChecks" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
          <i v-if="!showChecks" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
        </div>
        <b-collapse v-model="showChecks">
          <div v-for="(check, index) in rule.checks_attributes" :key="'checks_' + index">
            <div v-if="check._destroy != true" class="card p-3 mb-3">
              <p>
                <strong>{{ check.id == null ? "New " : "" }}Check</strong>
              </p>
              <CheckForm :rule="rule" :index="index" :check="check" :disabled="disabledForm" />
              <!-- Remove link -->
              <a
                v-if="!disabledForm"
                class="clickable text-dark"
                @click="$root.$emit('update:check', rule, { ...check, _destroy: true }, index)"
              >
                <i class="mdi mdi-trash-can" aria-hidden="true" />
                Remove Check
              </a>
            </div>
          </div>

          <b-button v-if="!disabledForm" class="mb-2" @click="$root.$emit('add:check', rule)"
            ><i class="mdi mdi-plus" />Add Check</b-button
          >
        </b-collapse>
      </template>
    </b-form>
  </div>
</template>

<script>
import RuleForm from "./RuleForm.vue";
import CheckForm from "./CheckForm.vue";
import DisaRuleDescriptionForm from "./DisaRuleDescriptionForm.vue";

export default {
  name: "AdvancedRuleForm",
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
    readOnly: {
      type: Boolean,
      default: false,
    },
  },
  data: function () {
    return {
      showChecks: false,
      showDisaRuleDescriptions: false,
      showRuleDescriptions: false,
    };
  },
  computed: {
    disabledForm: function () {
      return this.readOnly || this.rule.locked || this.rule.review_requestor_id ? true : false;
    },
  },
};
</script>

<style scoped></style>
