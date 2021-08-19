<template>
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
        :disabled="disabled"
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
        :disabled="disabled"
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
          :disabled="disabled"
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
          :disabled="disabled"
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
            :disabled="disabled"
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
            :disabled="disabled"
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
          :disabled="disabled"
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
          :disabled="disabled"
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
          :disabled="disabled"
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
          :disabled="disabled"
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
          :disabled="disabled"
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
          :disabled="disabled"
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
          :disabled="disabled"
        ></b-form-textarea>
      </b-form-group>
    </template>
  </b-form>
</template>

<script>
export default {
  name: 'RuleForm',
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
    disabled: {
      type: Boolean,
      required: true,
    },
  },
}
</script>

<style scoped>
</style>
