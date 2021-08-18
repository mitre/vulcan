<template>
  <div>
    <p class="text-danger" v-if="rule.locked">
      This control is locked and must first be unlocked if changes or deletion are required.
    </p>
    <b-form>
      <!-- status -->
      <b-form-group
        id="ruleEditor-status-group"
        label="Status"
        label-for="ruleEditor-status"
        description=""
      >
        <b-form-select
          id="ruleEditor-status"
          :options="statuses"
          v-model="rule.status"
          :disabled="rule.locked"
        ></b-form-select>
      </b-form-group>

      <!-- status_justification -->
      <b-form-group
        id="ruleEditor-status_justification-group"
        label="Status Justification"
        label-for="ruleEditor-status_justification"
        description=""
      >
        <b-form-textarea
          id="ruleEditor-status_justification"
          v-model="rule.status_justification"
          placeholder=""
          :disabled="rule.locked"
        ></b-form-textarea>
      </b-form-group>

      <!-- Some fields are only applicable if status is 'Applicable - Configurable' -->
      <p v-if="rule.status != 'Applicable - Configurable'"><small>Some fields are hidden due to the control's status.</small></p>
      <template v-if="rule.status == 'Applicable - Configurable'">
        <!-- title -->
        <b-form-group
          id="ruleEditor-title-group"
          label="Title"
          label-for="ruleEditor-"
          description=""
        >
          <b-form-input
            id="ruleEditor-title"
            v-model="rule.title"
            placeholder=""
            :disabled="rule.locked"
          ></b-form-input>
        </b-form-group>

        <!-- version -->
        <b-form-group
          id="ruleEditor--->-group"
          label="Version"
          label-for="ruleEditor--->"
          description=""
        >
          <b-form-input
            id="ruleEditor-version"
            v-model="rule.version"
            placeholder=""
            :disabled="rule.locked"
          ></b-form-input>
        </b-form-group>

        <div class="row">
          <!-- rule_severity -->
          <b-form-group
            id="ruleEditor-rule_severity-group"
            class="col-6"
            label="Rule Severity"
            label-for="ruleEditor-rule_severity"
            description=""
          >
            <b-form-select
              id="ruleEditor-rule_severity"
              :options="severities"
              v-model="rule.rule_severity"
              :disabled="rule.locked"
            ></b-form-select>
          </b-form-group>
          
          <!-- rule_weight -->
          <b-form-group
            id="ruleEditor-rule_weight-group"
            class="col-6"
            label="Rule Weight"
            label-for="ruleEditor-rule_weight"
            description=""
          >
            <b-form-input
              id="ruleEditor-rule_weight"
              v-model="rule.rule_weight"
              placeholder=""
              :disabled="rule.locked"
            ></b-form-input>
          </b-form-group>
        </div>

        <!-- artifact_description -->
        <b-form-group
          id="ruleEditor-artifact_description-group"
          label="Artifact Description"
          label-for="ruleEditor-artifact_description"
          description=""
        >
          <b-form-textarea
            id="ruleEditor-artifact_description"
            v-model="rule.artifact_description"
            placeholder=""
            :disabled="rule.locked"
          ></b-form-textarea>
        </b-form-group>

        <!-- fix_id -->
        <b-form-group
          id="ruleEditor-fix_id-group"
          label="Fix ID"
          label-for="ruleEditor-fix_id"
          description=""
        >
          <b-form-input
            id="ruleEditor-fix_id"
            v-model="rule.fix_id"
            placeholder=""
            :disabled="rule.locked"
          ></b-form-input>
        </b-form-group>

        <!-- fixtext -->
        <b-form-group
          id="ruleEditor-fixtext-group"
          label="Fix Text"
          label-for="ruleEditor-fixtext"
          description=""
        >
          <b-form-textarea
            id="ruleEditor-fixtext"
            v-model="rule.fixtext"
            placeholder=""
            :disabled="rule.locked"
          ></b-form-textarea>
        </b-form-group>

        <!-- fixtext_fixref -->
        <b-form-group
          id="ruleEditor-fixtext_fixref-group"
          label="Fix Test Reference"
          label-for="ruleEditor-fixtext_fixref"
          description=""
        >
          <b-form-input
            id="ruleEditor-fixtext_fixref"
            v-model="rule.fixtext_fixref"
            placeholder=""
            :disabled="rule.locked"
          ></b-form-input>
        </b-form-group>

        <!-- ident -->
        <b-form-group
          id="ruleEditor-ident-group"
          label="Identity"
          label-for="ruleEditor-ident"
          description=""
        >
          <b-form-input
            id="ruleEditor-ident"
            v-model="rule.ident"
            placeholder=""
            :disabled="rule.locked"
          ></b-form-input>
        </b-form-group>

        <!-- ident_system -->
        <b-form-group
          id="ruleEditor-ident_system-group"
          label="Identity System"
          label-for="ruleEditor-ident_system"
          description=""
        >
          <b-form-input
            id="ruleEditor-ident_system"
            v-model="rule.ident_system"
            placeholder=""
            :disabled="rule.locked"
          ></b-form-input>
        </b-form-group>

        <!-- vendor_comments -->
        <b-form-group
          id="ruleEditor-vendor_comments-group"
          label="Vendor Comments"
          label-for="ruleEditor-vendor_comments"
          description=""
        >
          <b-form-textarea
            id="ruleEditor-vendor_comments"
            v-model="rule.vendor_comments"
            placeholder=""
            :disabled="rule.locked"
          ></b-form-textarea>
        </b-form-group>

        <!-- rule_descriptions -->
        <!-- This is currently commented out to avoid confusion with DISA description schema -->
        <!-- <h2>Rule Descriptions</h2>
        <div :key="'rule_description_' + index" v-for="(rule_description, index) in rule.rule_descriptions_attributes">
          <div v-if="rule_description._destroy != true" class="card relationCard">
            <p><strong>{{dependentRecordCardHeader('Rule Description', rule_description)}}</strong></p>
            <b-form-group
              :id="'ruleEditor-rule_description-group-' + index"
              label="Rule Description"
              :label-for="'ruleEditor-rule_description' + index"
              description=""
            >
              <b-form-textarea
                :id="'ruleEditor-rule_description-' + index"
                v-model="rule_description.description"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-textarea>
            </b-form-group>
            <a @click="removeRuleDescription(index)" class="clickable text-dark" v-if="rule.locked == false">
              <i class="mdi mdi-trash-can" aria-hidden="true"></i>
              Remove Rule Description
            </a>
          </div>
        </div>
        <b-button class="mb-2" @click="addRuleDescription" v-if="rule.locked == false"><i class="mdi mdi-plus"></i>Add Description</b-button> -->

        <!-- disa_rule_description -->
        <h2>Rule Description</h2>
        <div :key="'disa_rule_description_' + index" v-for="(rule_description, index) in rule.disa_rule_descriptions_attributes">
          <div v-if="rule_description._destroy != true" class="card relationCard">
            <p><strong>{{dependentRecordCardHeader('Rule Description', rule_description)}}</strong></p>
            <!-- documentable -->
            <b-form-group description="">
              <b-form-checkbox v-model="rule_description.documentable" :disabled="rule.locked">Documentable</b-form-checkbox>
            </b-form-group>

            <!-- vuln_discussion -->
            <b-form-group
              :id="'ruleEditor-disa_rule_description-vuln_discussion-group-' + index"
              label="Vulnerability Discussion"
              :label-for="'ruleEditor-disa_rule_description-vuln_discussion-' + index"
              description=""
            >
              <b-form-textarea
                :id="'ruleEditor-disa_rule_description-vuln_discussion-' + index"
                v-model="rule_description.vuln_discussion"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-textarea>
            </b-form-group>

            <!-- false_positives -->
            <b-form-group
              :id="'ruleEditor-disa_rule_description-false_positives-group-' + index"
              label="False Positives"
              :label-for="'ruleEditor-disa_rule_description-false_positives-' + index"
              description=""
            >
              <b-form-textarea
                :id="'ruleEditor-disa_rule_description-false_positives-' + index"
                v-model="rule_description.false_positives"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-textarea>
            </b-form-group>

            <!-- false_negatives -->
            <b-form-group
              :id="'ruleEditor-disa_rule_description-false_negatives-group-' + index"
              label="False Negatives"
              :label-for="'ruleEditor-disa_rule_description-false_negatives-' + index"
              description=""
            >
              <b-form-textarea
                :id="'ruleEditor-disa_rule_description-false_negatives-' + index"
                v-model="rule_description.false_negatives"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-textarea>
            </b-form-group>

            <!-- mitigations -->
            <b-form-group
              :id="'ruleEditor-disa_rule_description-mitigations-group-' + index"
              label="Mitigations"
              :label-for="'ruleEditor-disa_rule_description-mitigations-' + index"
              description=""
            >
              <b-form-textarea
                :id="'ruleEditor-disa_rule_description-mitigations-' + index"
                v-model="rule_description.mitigations"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-textarea>
            </b-form-group>

            <!-- severity_override_guidance -->
            <b-form-group
              :id="'ruleEditor-disa_rule_description-severity_override_guidance-group-' + index"
              label="Security Override Guidance"
              :label-for="'ruleEditor-disa_rule_description-severity_override_guidance-' + index"
              description=""
            >
              <b-form-textarea
                :id="'ruleEditor-disa_rule_description-severity_override_guidance-' + index"
                v-model="rule_description.severity_override_guidance"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-textarea>
            </b-form-group>
            
            <!-- potential_impacts -->
            <b-form-group
              :id="'ruleEditor-disa_rule_description-potential_impacts-group-' + index"
              label="Potential Impacts"
              :label-for="'ruleEditor-disa_rule_description-potential_impacts-' + index"
              description=""
            >
              <b-form-textarea
                :id="'ruleEditor-disa_rule_description-potential_impacts-' + index"
                v-model="rule_description.potential_impacts"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-textarea>
            </b-form-group>

            <!-- third_party_tools -->
            <b-form-group
              :id="'ruleEditor-disa_rule_description-third_party_tools-group-' + index"
              label="Third Party Tools"
              :label-for="'ruleEditor-disa_rule_description-third_party_tools-' + index"
              description=""
            >
              <b-form-textarea
                :id="'ruleEditor-disa_rule_description-third_party_tools-' + index"
                v-model="rule_description.third_party_tools"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-textarea>
            </b-form-group>

            <!-- mitigation_control -->
            <b-form-group
              :id="'ruleEditor-disa_rule_description-mitigation_control-group-' + index"
              label="Mitigation Control"
              :label-for="'ruleEditor-disa_rule_description-mitigation_control-' + index"
              description=""
            >
              <b-form-textarea
                :id="'ruleEditor-disa_rule_description-mitigation_control-' + index"
                v-model="rule_description.mitigation_control"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-textarea>
            </b-form-group>

            <!-- responsibility -->
            <b-form-group
              :id="'ruleEditor-disa_rule_description-responsibility-group-' + index"
              label="Responsibility"
              :label-for="'ruleEditor-disa_rule_description-responsibility-' + index"
              description=""
            >
              <b-form-textarea
                :id="'ruleEditor-disa_rule_description-responsibility-' + index"
                v-model="rule_description.responsibility"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-textarea>
            </b-form-group>

            <!-- ia_controls -->
            <b-form-group
              :id="'ruleEditor-disa_rule_description-ia_controls-group-' + index"
              label="IA Controls"
              :label-for="'ruleEditor-disa_rule_description-ia_controls-' + index"
              description=""
            >
              <b-form-textarea
                :id="'ruleEditor-disa_rule_description-ia_controls-' + index"
                v-model="rule_description.ia_controls"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-textarea>
            </b-form-group>
            <!-- This is commented out because there is currently the assumption that users will only need one description -->
            <!-- <a @click="removeDisaRuleDescription(index)" class="clickable text-dark" v-if="rule.locked == false">
              <i class="mdi mdi-trash-can" aria-hidden="true"></i>
              Remove DISA Description
            </a> -->
          </div>
        </div>
        <!-- This is commented out because there is currently the assumption that users will only need one description -->
        <!-- <b-button class="mb-2" @click="addDisaRuleDescription" v-if="rule.locked == false"><i class="mdi mdi-plus"></i>Add DISA Description</b-button> -->

        <!-- checks -->
        <h2>Checks</h2>
        <div :key="'checks_' + index" v-for="(check, index) in rule.checks_attributes">
          <div v-if="check._destroy != true"  class="card relationCard">
            <p><strong>{{dependentRecordCardHeader('Check', check)}}</strong></p>
            <b-form-group
              :id="'ruleEditor-check-group-' + index"
              label="System"
              :label-for="'ruleEditor-check-system-' + index"
              description=""
            > 
              <b-form-input
                :id="'ruleEditor-check-system-' + index"
                v-model="check.system"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-input>
            </b-form-group>

            <b-form-group
              :id="'ruleEditor-check-group-' + index"
              label="Reference Name"
              :label-for="'ruleEditor-check-content_ref_name-' + index"
              description=""
            > 
              <b-form-input
                :id="'ruleEditor-check-content_ref_name-' + index"
                v-model="check.content_ref_name"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-input>
            </b-form-group>

            <b-form-group
              :id="'ruleEditor-check-group-' + index"
              label="Reference Link"
              :label-for="'ruleEditor-check-content_ref_href-' + index"
              description=""
            > 
              <b-form-input
                :id="'ruleEditor-check-content_ref_href-' + index"
                v-model="check.content_ref_href"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-input>
            </b-form-group>

            <b-form-group
              :id="'ruleEditor-check-group-' + index"
              label="Check"
              :label-for="'ruleEditor-check-content-' + index"
              description=""
            > 
              <b-form-textarea
                :id="'ruleEditor-check-content-' + index"
                v-model="check.content"
                placeholder=""
                :disabled="rule.locked"
              ></b-form-textarea>
            </b-form-group>
            <a @click="removeCheck(index)" class="clickable text-dark" v-if="rule.locked == false">
              <i class="mdi mdi-trash-can" aria-hidden="true"></i>
              Remove Check
            </a>
          </div>
        </div>
        <b-button class="mb-2" @click="addCheck" v-if="rule.locked == false"><i class="mdi mdi-plus"></i>Add Check</b-button>
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
    dependentRecordCardHeader(name, record) {
      if (record.id) {
        return name;
      }
      return `New ${name}`;
    }
  }
}
</script>

<style scoped>
.relationCard {
  padding: 1em;
  margin-bottom: 1em;
}
</style>
