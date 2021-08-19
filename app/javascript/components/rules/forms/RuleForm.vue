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
        :class="inputClass('status')"
        :options="statuses"
        v-model="rule.status"
        :disabled="disabled"
      ></b-form-select>
      <b-form-valid-feedback v-if="hasValidFeedback('status')">
        {{this.validFeedback['status']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('status')">
        {{this.invalidFeedback['status']}}
      </b-form-invalid-feedback>
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
        :class="inputClass('status_justification')"
        v-model="rule.status_justification"
        placeholder=""
        :disabled="disabled"
        rows="1"
        max-rows="99"
      ></b-form-textarea>
      <b-form-valid-feedback v-if="hasValidFeedback('status_justification')">
        {{this.validFeedback['status_justification']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('status_justification')">
        {{this.invalidFeedback['status_justification']}}
      </b-form-invalid-feedback>
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
          :class="inputClass('title')"
          v-model="rule.title"
          placeholder=""
          :disabled="disabled"
        ></b-form-input>
        <b-form-valid-feedback v-if="hasValidFeedback('title')">
          {{this.validFeedback['title']}}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('title')">
          {{this.invalidFeedback['title']}}
        </b-form-invalid-feedback>
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
          :class="inputClass('version')"
          v-model="rule.version"
          placeholder=""
          :disabled="disabled"
        ></b-form-input>
        <b-form-valid-feedback v-if="hasValidFeedback('version')">
          {{this.validFeedback['version']}}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('version')">
          {{this.invalidFeedback['version']}}
        </b-form-invalid-feedback>
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
            :class="inputClass('rule_severity')"
            :options="severities"
            v-model="rule.rule_severity"
            :disabled="disabled"
          ></b-form-select>
          <b-form-valid-feedback v-if="hasValidFeedback('rule_severity')">
            {{this.validFeedback['rule_severity']}}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('rule_severity')">
            {{this.invalidFeedback['rule_severity']}}
          </b-form-invalid-feedback>
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
            :class="inputClass('rule_weight')"
            v-model="rule.rule_weight"
            placeholder=""
            :disabled="disabled"
          ></b-form-input>
          <b-form-valid-feedback v-if="hasValidFeedback('rule_weight')">
            {{this.validFeedback['rule_weight']}}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('rule_weight')">
            {{this.invalidFeedback['rule_weight']}}
          </b-form-invalid-feedback>
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
          :class="inputClass('artifact_description')"
          v-model="rule.artifact_description"
          placeholder=""
          :disabled="disabled"
          rows="1"
          max-rows="99"
        ></b-form-textarea>
        <b-form-valid-feedback v-if="hasValidFeedback('artifact_description')">
          {{this.validFeedback['artifact_description']}}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('artifact_description')">
          {{this.invalidFeedback['artifact_description']}}
        </b-form-invalid-feedback>
      </b-form-group>

      <div class="row">
        <div class="col-6">
          <!-- fix_id -->
          <b-form-group
            id="ruleEditor-fix_id-group"
            label="Fix ID"
            label-for="ruleEditor-fix_id"
            description=""
          >
            <b-form-input
              id="ruleEditor-fix_id"
              :class="inputClass('fix_id')"
              v-model="rule.fix_id"
              placeholder=""
              :disabled="disabled"
            ></b-form-input>
            <b-form-valid-feedback v-if="hasValidFeedback('fix_id')">
              {{this.validFeedback['fix_id']}}
            </b-form-valid-feedback>
            <b-form-invalid-feedback v-if="hasInvalidFeedback('fix_id')">
              {{this.invalidFeedback['fix_id']}}
            </b-form-invalid-feedback>
          </b-form-group>
        </div>

        <div class="col-6">
          <!-- fixtext_fixref -->
          <b-form-group
            id="ruleEditor-fixtext_fixref-group"
            label="Fix Text Reference"
            label-for="ruleEditor-fixtext_fixref"
            description=""
          >
            <b-form-input
              id="ruleEditor-fixtext_fixref"
              :class="inputClass('fixtext_fixref')"
              v-model="rule.fixtext_fixref"
              placeholder=""
              :disabled="disabled"
            ></b-form-input>
            <b-form-valid-feedback v-if="hasValidFeedback('fixtext_fixref')">
              {{this.validFeedback['fixtext_fixref']}}
            </b-form-valid-feedback>
            <b-form-invalid-feedback v-if="hasInvalidFeedback('fixtext_fixref')">
              {{this.invalidFeedback['fixtext_fixref']}}
            </b-form-invalid-feedback>
          </b-form-group>
        </div>
      </div>

      <!-- fixtext -->
      <b-form-group
        id="ruleEditor-fixtext-group"
        label="Fix Text"
        label-for="ruleEditor-fixtext"
        description=""
      >
        <b-form-textarea
          id="ruleEditor-fixtext"
          :class="inputClass('fixtext')"
          v-model="rule.fixtext"
          placeholder=""
          :disabled="disabled"
          rows="1"
          max-rows="99"
        ></b-form-textarea>
        <b-form-valid-feedback v-if="hasValidFeedback('fixtext')">
          {{this.validFeedback['fixtext']}}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('fixtext')">
          {{this.invalidFeedback['fixtext']}}
        </b-form-invalid-feedback>
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
          :class="inputClass('ident')"
          v-model="rule.ident"
          placeholder=""
          :disabled="disabled"
        ></b-form-input>
        <b-form-valid-feedback v-if="hasValidFeedback('ident')">
          {{this.validFeedback['ident']}}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('ident')">
          {{this.invalidFeedback['ident']}}
        </b-form-invalid-feedback>
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
          :class="inputClass('ident_system')"
          v-model="rule.ident_system"
          placeholder=""
          :disabled="disabled"
        ></b-form-input>
        <b-form-valid-feedback v-if="hasValidFeedback('ident_system')">
          {{this.validFeedback['ident_system']}}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('ident_system')">
          {{this.invalidFeedback['ident_system']}}
        </b-form-invalid-feedback>
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
          :class="inputClass('vendor_comments')"
          v-model="rule.vendor_comments"
          placeholder=""
          :disabled="disabled"
          rows="1"
          max-rows="99"
        ></b-form-textarea>
        <b-form-valid-feedback v-if="hasValidFeedback('vendor_comments')">
          {{this.validFeedback['vendor_comments']}}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('vendor_comments')">
          {{this.invalidFeedback['vendor_comments']}}
        </b-form-invalid-feedback>
      </b-form-group>
    </template>
  </b-form>
</template>

<script>
import FormFeedbackMixinVue from '../../../mixins/FormFeedbackMixin.vue';
export default {
  name: 'RuleForm',
  mixins: [FormFeedbackMixinVue],
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
