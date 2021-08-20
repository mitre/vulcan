<template>
  <div>
    <p class="text-danger" v-if="rule.locked">
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
            :description="description"
            :disabled="rule.locked" 
            :index="index"
            @removeRuleDescription="(index) => removeRuleDescription(index)"
          />
          <b-button class="mb-2" @click="addRuleDescription" v-if="rule.locked == false"><i class="mdi mdi-plus"></i>Add Description</b-button>
        </b-collapse>
      </template> -->

      <!-- disa_rule_description -->
      <template v-if="rule.status == 'Applicable - Configurable'">
        <div @click="showDisaRuleDescriptions = !showDisaRuleDescriptions" class="clickable mb-2">
          <h2 class="m-0 d-inline-block">Rule Description</h2>
          <!-- <b-badge pill class="superVerticalAlign">{{rule.disa_rule_descriptions_attributes.length}}</b-badge> -->

          <i class="mdi mdi-menu-down superVerticalAlign collapsableArrow" v-if="showDisaRuleDescriptions"></i>
          <i class="mdi mdi-menu-up superVerticalAlign collapsableArrow" v-if="!showDisaRuleDescriptions"></i>
        </div>
        <b-collapse v-model="showDisaRuleDescriptions">
          <DisaRuleDescriptionForm
            :key="'disa_rule_description_' + index"
            v-for="(description, index) in rule.disa_rule_descriptions_attributes"
            :description="description"
            :disabled="rule.locked" 
            :index="index"
            @removeDisaRuleDescription="(index) => removeDisaRuleDescription(index)"
          />
          <!-- This is commented out because there is currently the assumption that users will only need one description -->
          <!-- <b-button class="mb-2" @click="addDisaRuleDescription" v-if="rule.locked == false"><i class="mdi mdi-plus"></i>Add DISA Description</b-button> -->
        </b-collapse>
      </template>

      <!-- checks -->
      <template v-if="rule.status == 'Applicable - Configurable'">
        <div @click="showChecks = !showChecks" class="clickable mb-2">
          <h2 class="m-0 d-inline-block">Checks</h2>
          <b-badge pill class="superVerticalAlign">{{rule.checks_attributes.length}}</b-badge>

          <i class="mdi mdi-menu-down superVerticalAlign collapsableArrow" v-if="showChecks"></i>
          <i class="mdi mdi-menu-up superVerticalAlign collapsableArrow" v-if="!showChecks"></i>
        </div>
        <b-collapse v-model="showChecks">
          <CheckForm
            :key="'checks_' + index"
            v-for="(check, index) in rule.checks_attributes"
            :check="check"
            :disabled="rule.locked" 
            :index="index"
            @removeCheck="(index) => removeCheck(index)"
          />
          <b-button class="mb-2" @click="addCheck" v-if="rule.locked == false"><i class="mdi mdi-plus"></i>Add Check</b-button>
        </b-collapse>
      </template>
    </b-form>
  </div>
</template>

<script>
export default {
  name: 'RuleEditor',
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
    }
  },
  data: function() {
    return {
      showChecks: false,
      showDisaRuleDescriptions: false,
      showRuleDescriptions: false
    }
  },
  methods: {
    addRuleDescription: function() {
      this.rule.rule_descriptions_attributes.push({ description: '', rule_id: this.rule.id, _destroy: false });
    },
    removeRuleDescription: function(index) {
      this.rule.rule_descriptions_attributes[index]._destroy = true
    },
    addCheck: function() {
      this.rule.checks_attributes.push({ system: '', content_ref_name: '', content_ref_href: '', content: '', rule_id: this.rule.id, _destroy: false });
    },
    removeCheck: function(index) {
      this.rule.checks_attributes[index]._destroy = true
    },
    addDisaRuleDescription: function() {
      this.rule.disa_rule_descriptions_attributes.push({ description: '', rule_id: this.rule.id, _destroy: false });
    },
    removeDisaRuleDescription: function(index) {
      this.rule.disa_rule_descriptions_attributes[index]._destroy = true
    },
  }
}
</script>

<style scoped>
</style>