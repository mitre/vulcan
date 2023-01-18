<template>
  <div>
    <div class="clickable mb-2" @click="showSrgInformation = !showSrgInformation">
      <h2 class="m-0 d-inline-block">Security Requirements Guide Information</h2>
      <i v-if="showSrgInformation" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
      <i v-if="!showSrgInformation" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
    </div>
    <b-collapse v-model="showSrgInformation">
      <div class="row">
        <div class="col-4">
          <!-- nist_control (aka IA Control) -->
          <strong>IA Control</strong>
          <i
            v-if="tooltips['nist_control']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['nist_control']"
          />
        </div>
        <div class="col-8">
          {{ nist_control_family }}
        </div>
      </div>
      <div class="row">
        <div class="col-4">
          <!-- cci -->
          <strong>CCI</strong>
          <i
            v-if="tooltips['cci']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['cci']"
          />
        </div>
        <div class="col-8">
          {{ cci }}
        </div>
      </div>
      <div class="row">
        <div class="col-4">
          <!-- srg_requirement -->
          <strong>SRG Requirement</strong>
          <i
            v-if="tooltips['srg_requirement']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['srg_requirement']"
          />
        </div>
        <div class="col-8">{{ srg_rule.title }}</div>
      </div>
      <div class="row">
        <div class="col-4">
          <!-- srg_vuln_discussion -->
          <strong>SRG Vulnerability Discussion</strong>
          <i
            v-if="tooltips['srg_vuln_discussion']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['srg_vuln_discussion']"
          />
        </div>
        <div class="col-8">{{ srg_rule.disa_rule_descriptions_attributes[0].vuln_discussion }}</div>
      </div>
      <div class="row">
        <div class="col-4">
          <!-- srg_check_text -->
          <strong>SRG Check Text</strong>
          <i
            v-if="tooltips['srg_check_text']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['srg_check_text']"
          />
        </div>
        <div class="col-8">{{ srg_rule.checks_attributes[0].content }}</div>
      </div>
      <div class="row">
        <div class="col-4">
          <!-- srg_fix_text -->
          <strong>SRG Fix Text</strong>
          <i
            v-if="tooltips['srg_fix_text']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['srg_fix_text']"
          />
        </div>
        <div class="col-8">{{ srg_rule.fixtext }}</div>
      </div>
      <div class="row">
        <div class="col-4">
          <!-- srg_version aka ID -->
          <strong>SRG ID</strong>
          <i
            v-if="tooltips['srg_id']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['srg_id']"
          />
        </div>
        <div class="col-8">{{ srg_rule.version }}</div>
      </div>
    </b-collapse>
  </div>
</template>
<script>
export default {
  name: "RuleSecurityRequirementsGuideInformation",
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
  },
  data: function () {
    return {
      tooltips: {
        nist_control:
          "The NIST SP 800-53 Revision 4 Control Family that maps to the Common Control Indicator (CCI)",
        cci:
          "The Control Correlation Identifier (CCI) enables DoD organizations to trace STIG compliance to Information Assurance controls specified by the National Institutes of Standards and Technology (NIST) and mandated for Federal government agencies.",
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
      },
      showSrgInformation: false,
    };
  },
};
</script>
<style scoped></style>
