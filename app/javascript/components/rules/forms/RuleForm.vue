<template>
  <b-form>
    <!-- status -->
    <b-form-group :id="`ruleEditor-status-group-${mod}`">
      <label :for="`ruleEditor-status-${mod}`">
        Status
        <i
          v-if="tooltips['status']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['status']"
        />
      </label>
      <b-form-select
        :id="`ruleEditor-status-${mod}`"
        v-model="ruleCopy.status"
        :class="inputClass('status')"
        :options="statuses"
        :disabled="disabled"
        @input="$root.$emit('update:rule', ruleCopy)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('status')">
        {{ validFeedback["status"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('status')">
        {{ invalidFeedback["status"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- status_justification -->
    <b-form-group :id="`ruleEditor-status_justification-group-${mod}`">
      <label :for="`ruleEditor-status_justification-${mod}`">
        Status Justification
        <i
          v-if="tooltips['status_justification']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['status_justification']"
        />
      </label>
      <b-form-textarea
        :id="`ruleEditor-status_justification-${mod}`"
        v-model="ruleCopy.status_justification"
        :class="inputClass('status_justification')"
        placeholder=""
        :disabled="disabled"
        rows="1"
        max-rows="99"
        @input="$root.$emit('update:rule', ruleCopy)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('status_justification')">
        {{ validFeedback["status_justification"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('status_justification')">
        {{ invalidFeedback["status_justification"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- Some fields are only applicable if status is 'Applicable - Configurable' -->
    <p v-if="ruleCopy.status != 'Applicable - Configurable'">
      <small>Some fields are hidden due to the control's status.</small>
    </p>
    <template v-if="ruleCopy.status == 'Applicable - Configurable'">
      <!-- title -->
      <b-form-group :id="`ruleEditor-title-group-${mod}`">
        <label :for="`ruleEditor-title-${mod}`">
          Title
          <i
            v-if="tooltips['title']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['title']"
          />
        </label>
        <b-form-input
          :id="`ruleEditor-title-${mod}`"
          v-model="ruleCopy.title"
          :class="inputClass('title')"
          placeholder=""
          :disabled="disabled"
          @input="$root.$emit('update:rule', ruleCopy)"
        />
        <b-form-valid-feedback v-if="hasValidFeedback('title')">
          {{ validFeedback["title"] }}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('title')">
          {{ invalidFeedback["title"] }}
        </b-form-invalid-feedback>
      </b-form-group>

      <!-- version -->
      <b-form-group :id="`ruleEditor-version-group-${mod}`">
        <label :for="`ruleEditor-version-${mod}`">
          Version
          <i
            v-if="tooltips['version']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['version']"
          />
        </label>
        <b-form-input
          :id="`ruleEditor-version-${mod}`"
          v-model="ruleCopy.version"
          :class="inputClass('version')"
          placeholder=""
          :disabled="disabled"
          @input="$root.$emit('update:rule', ruleCopy)"
        />
        <b-form-valid-feedback v-if="hasValidFeedback('version')">
          {{ validFeedback["version"] }}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('version')">
          {{ invalidFeedback["version"] }}
        </b-form-invalid-feedback>
      </b-form-group>

      <div class="row">
        <!-- rule_severity -->
        <b-form-group :id="`ruleEditor-rule_severity-group-${mod}`" class="col-6">
          <label :for="`ruleEditor-rule_severity-${mod}`">
            Rule Severity
            <i
              v-if="tooltips['rule_severity']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['rule_severity']"
            />
          </label>
          <b-form-select
            :id="`ruleEditor-rule_severity-${mod}`"
            v-model="ruleCopy.rule_severity"
            :class="inputClass('rule_severity')"
            :options="severities"
            :disabled="disabled"
            @input="$root.$emit('update:rule', ruleCopy)"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('rule_severity')">
            {{ validFeedback["rule_severity"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('rule_severity')">
            {{ invalidFeedback["rule_severity"] }}
          </b-form-invalid-feedback>
        </b-form-group>

        <!-- rule_weight -->
        <b-form-group :id="`ruleEditor-rule_weight-group-${mod}`" class="col-6">
          <label :for="`ruleEditor-rule_weight-${mod}`">
            Rule Weight
            <i
              v-if="tooltips['rule_weight']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['rule_weight']"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-rule_weight-${mod}`"
            v-model="ruleCopy.rule_weight"
            :class="inputClass('rule_weight')"
            placeholder=""
            :disabled="disabled"
            @input="$root.$emit('update:rule', ruleCopy)"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('rule_weight')">
            {{ validFeedback["rule_weight"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('rule_weight')">
            {{ invalidFeedback["rule_weight"] }}
          </b-form-invalid-feedback>
        </b-form-group>
      </div>

      <!-- artifact_description -->
      <b-form-group :id="`ruleEditor-artifact_description-group-${mod}`">
        <label :for="`ruleEditor-artifact_description-${mod}`">
          Artifact Description
          <i
            v-if="tooltips['artifact_description']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['artifact_description']"
          />
        </label>
        <b-form-textarea
          :id="`ruleEditor-artifact_description-${mod}`"
          v-model="ruleCopy.artifact_description"
          :class="inputClass('artifact_description')"
          placeholder=""
          :disabled="disabled"
          rows="1"
          max-rows="99"
          @input="$root.$emit('update:rule', ruleCopy)"
        />
        <b-form-valid-feedback v-if="hasValidFeedback('artifact_description')">
          {{ validFeedback["artifact_description"] }}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('artifact_description')">
          {{ invalidFeedback["artifact_description"] }}
        </b-form-invalid-feedback>
      </b-form-group>

      <div class="row">
        <!-- fix_id -->
        <b-form-group :id="`ruleEditor-fix_id-group-${mod}`" class="col-6">
          <label :for="`ruleEditor-fix_id-${mod}`">
            Fix ID
            <i
              v-if="tooltips['fix_id']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['fix_id']"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-fix_id-${mod}`"
            v-model="ruleCopy.fix_id"
            :class="inputClass('fix_id')"
            placeholder=""
            :disabled="disabled"
            @input="$root.$emit('update:rule', ruleCopy)"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('fix_id')">
            {{ validFeedback["fix_id"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('fix_id')">
            {{ invalidFeedback["fix_id"] }}
          </b-form-invalid-feedback>
        </b-form-group>

        <!-- fixtext_fixref -->
        <b-form-group :id="`ruleEditor-fixtext_fixref-group-${mod}`" class="col-6">
          <label :for="`ruleEditor-fixtext_fixref-${mod}`">
            Fix Text Reference
            <i
              v-if="tooltips['fixtext_fixref']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['fixtext_fixref']"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-fixtext_fixref-${mod}`"
            v-model="ruleCopy.fixtext_fixref"
            :class="inputClass('fixtext_fixref')"
            placeholder=""
            :disabled="disabled"
            @input="$root.$emit('update:rule', ruleCopy)"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('fixtext_fixref')">
            {{ validFeedback["fixtext_fixref"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('fixtext_fixref')">
            {{ invalidFeedback["fixtext_fixref"] }}
          </b-form-invalid-feedback>
        </b-form-group>
      </div>

      <!-- fixtext -->
      <b-form-group :id="`ruleEditor-fixtext-group-${mod}`">
        <label :for="`ruleEditor-fixtext-${mod}`">
          Fix Text
          <i
            v-if="tooltips['fixtext']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['fixtext']"
          />
        </label>
        <b-form-textarea
          :id="`ruleEditor-fixtext-${mod}`"
          v-model="ruleCopy.fixtext"
          :class="inputClass('fixtext')"
          placeholder=""
          :disabled="disabled"
          rows="1"
          max-rows="99"
          @input="$root.$emit('update:rule', ruleCopy)"
        />
        <b-form-valid-feedback v-if="hasValidFeedback('fixtext')">
          {{ validFeedback["fixtext"] }}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('fixtext')">
          {{ invalidFeedback["fixtext"] }}
        </b-form-invalid-feedback>
      </b-form-group>

      <div class="row">
        <!-- ident -->
        <b-form-group :id="`ruleEditor-ident-group-${mod}`" class="col-4">
          <label :for="`ruleEditor-ident-${mod}`">
            Identity
            <i
              v-if="tooltips['ident']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['ident']"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-ident-${mod}`"
            v-model="ruleCopy.ident"
            :class="inputClass('ident')"
            placeholder=""
            :disabled="disabled"
            @input="$root.$emit('update:rule', ruleCopy)"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('ident')">
            {{ validFeedback["ident"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('ident')">
            {{ invalidFeedback["ident"] }}
          </b-form-invalid-feedback>
        </b-form-group>

        <!-- ident_system -->
        <b-form-group :id="`ruleEditor-ident_system-group-${mod}`" class="col-8">
          <label :for="`ruleEditor-ident_system-${mod}`">
            Identity System
            <i
              v-if="tooltips['ident_system']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['ident_system']"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-ident_system-${mod}`"
            v-model="ruleCopy.ident_system"
            :class="inputClass('ident_system')"
            placeholder=""
            :disabled="disabled"
            @input="$root.$emit('update:rule', ruleCopy)"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('ident_system')">
            {{ validFeedback["ident_system"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('ident_system')">
            {{ invalidFeedback["ident_system"] }}
          </b-form-invalid-feedback>
        </b-form-group>
      </div>

      <!-- vendor_comments -->
      <b-form-group :id="`ruleEditor-vendor_comments-group-${mod}`">
        <label :for="`ruleEditor-vendor_comments-${mod}`">
          Vendor Comments
          <i
            v-if="tooltips['vendor_comments']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['vendor_comments']"
          />
        </label>
        <b-form-textarea
          :id="`ruleEditor-vendor_comments-${mod}`"
          v-model="ruleCopy.vendor_comments"
          :class="inputClass('vendor_comments')"
          placeholder=""
          :disabled="disabled"
          rows="1"
          max-rows="99"
        />
        <b-form-valid-feedback v-if="hasValidFeedback('vendor_comments')">
          {{ validFeedback["vendor_comments"] }}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('vendor_comments')">
          {{ invalidFeedback["vendor_comments"] }}
        </b-form-invalid-feedback>
      </b-form-group>
    </template>
  </b-form>
</template>

<script>
import FormFeedbackMixinVue from "../../../mixins/FormFeedbackMixin.vue";
import _ from "lodash";

export default {
  name: "RuleForm",
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
  data: function () {
    return {
      mod: Math.floor(Math.random() * 1000),
      ruleCopy: _.cloneDeep(this.rule),
      tooltips: {
        status: null,
        status_justification: null,
        title: null,
        version: null,
        rule_severity: null,
        rule_weight: null,
        artifact_description: null,
        fix_id: null,
        fixtext_fixref: null,
        fixtext: null,
        ident: null,
        ident_system: null,
        vendor_comments: null,
      },
    };
  },
};
</script>

<style scoped></style>
