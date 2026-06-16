<template>
  <div>
    <div class="clickable mb-2" @click="showSrgInformation = !showSrgInformation">
      <h2 class="m-0 d-inline-block">Security Requirements Guide Information</h2>
      <b-icon v-if="showSrgInformation" icon="chevron-down" />
      <b-icon v-if="!showSrgInformation" icon="chevron-up" />
    </div>
    <b-collapse v-model="showSrgInformation">
      <b-form-group label-cols-md="3" label-align-md="right" class="mb-2">
        <template #label>
          IA Control
          <InfoTooltip v-if="tooltips['nist_control']" :text="tooltips['nist_control']" />
        </template>
        {{ nist_control_family }}
      </b-form-group>

      <b-form-group label-cols-md="3" label-align-md="right" class="mb-2">
        <template #label>
          CCI
          <InfoTooltip v-if="tooltips['cci']" :text="tooltips['cci']" />
        </template>
        {{ cci }}
      </b-form-group>

      <b-form-group label-cols-md="3" label-align-md="right" class="mb-2">
        <template #label>
          SRG Requirement
          <InfoTooltip v-if="tooltips['srg_requirement']" :text="tooltips['srg_requirement']" />
        </template>
        {{ srg_rule.title }}
      </b-form-group>

      <b-form-group label-cols-md="3" label-align-md="right" class="mb-2">
        <template #label>
          SRG Vulnerability Discussion
          <InfoTooltip
            v-if="tooltips['srg_vuln_discussion']"
            :text="tooltips['srg_vuln_discussion']"
          />
        </template>
        {{ srg_rule.disa_rule_descriptions_attributes[0].vuln_discussion }}
      </b-form-group>

      <b-form-group label-cols-md="3" label-align-md="right" class="mb-2">
        <template #label>
          SRG Check Text
          <InfoTooltip v-if="tooltips['srg_check_text']" :text="tooltips['srg_check_text']" />
        </template>
        {{ srg_rule.checks_attributes[0].content }}
      </b-form-group>

      <b-form-group label-cols-md="3" label-align-md="right" class="mb-2">
        <template #label>
          SRG Fix Text
          <InfoTooltip v-if="tooltips['srg_fix_text']" :text="tooltips['srg_fix_text']" />
        </template>
        {{ srg_rule.fixtext }}
      </b-form-group>

      <b-form-group label-cols-md="3" label-align-md="right" class="mb-2">
        <template #label>
          SRG ID
          <InfoTooltip v-if="tooltips['srg_id']" :text="tooltips['srg_id']" />
        </template>
        {{ srg_rule.version }}
      </b-form-group>

      <b-form-group label-cols-md="3" label-align-md="right" class="mb-2">
        <template #label>
          SRG Version
          <InfoTooltip v-if="tooltips['srg_version']" :text="tooltips['srg_version']" />
        </template>
        {{ srg_info.version }}
      </b-form-group>
    </b-collapse>
  </div>
</template>
<script>
import InfoTooltip from "../shared/InfoTooltip.vue";

export default {
  name: "RuleSecurityRequirementsGuideInformation",
  components: { InfoTooltip },
  props: {
    nist_control_family: {
      type: String,
      required: true,
    },
    srg_rule: {
      type: Object,
      required: true,
    },
    cci: {
      type: String,
      required: true,
    },
    srg_info: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return {
      tooltips: {
        nist_control:
          "The NIST SP 800-53 Revision 4 Control Family that maps to the Common Control Indicator (CCI)",
        cci: "The Control Correlation Identifier (CCI) enables DoD organizations to trace STIG compliance to Information Assurance controls specified by the National Institutes of Standards and Technology (NIST) and mandated for Federal government agencies.",
        srg_requirement:
          "This is a sentence stating the requirement and is pre-populated from the Technology SRG.",
        srg_vuln_discussion:
          "The vulnerability discussion describes the risk of not complying with the requirement that is pre-populated from the Technology SRG.",
        srg_check_text:
          "The SRG Check Content provides a broad method of review and inspection. The STIG developer can use this information to determine what areas to inspect in the STIG.",
        srg_fix_text:
          "The SRG Fix Text provides a broad method of how to correct a system. The STIG developer can use this information to determine what areas to address in the STIG.",
        srg_id:
          "This is the ID for the SRG requirement. It may also contain identification information for a parent SRG document. May not be unique for a given STIG",
        srg_version: "Version and Release of SRG requirement.",
      },
      showSrgInformation: false,
    };
  },
};
</script>
