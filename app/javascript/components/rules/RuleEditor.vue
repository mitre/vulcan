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
      <!-- <h2>Rule Descriptions</h2>
      <RuleDescriptionForm 
        :key="'rule_description_' + index" 
        v-for="(description, index) in rule.rule_descriptions_attributes"
        :description="description"
        :disabled="rule.locked" 
        :index="index"
        @removeRuleDescription="(index) => removeRuleDescription(index)"
      />
      <b-button class="mb-2" @click="addRuleDescription" v-if="rule.locked == false"><i class="mdi mdi-plus"></i>Add Description</b-button> -->

      <!-- disa_rule_description -->
      <h2>Rule Description</h2>
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

      <!-- checks -->
      <h2>Checks</h2>
      <CheckForm
        :key="'checks_' + index"
        v-for="(check, index) in rule.checks_attributes"
        :check="check"
        :disabled="rule.locked" 
        :index="index"
        @removeCheck="(index) => removeCheck(index)"
      />
      <b-button class="mb-2" @click="addCheck" v-if="rule.locked == false"><i class="mdi mdi-plus"></i>Add Check</b-button>
      
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
.relationCard {
  padding: 1em;
  margin-bottom: 1em;
}
</style>
