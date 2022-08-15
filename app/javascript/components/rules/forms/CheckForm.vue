<template>
  <div v-if="check._destroy != true">
    <!-- system -->
    <b-form-group
      v-if="fields.displayed.includes('system')"
      :id="`ruleEditor-check-system-group-${mod}`"
    >
      <label :for="`ruleEditor-check-system-${mod}`">
        System
        <i
          v-if="tooltips['system']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['system']"
        />
      </label>
      <b-form-input
        :id="`ruleEditor-check-system-${mod}`"
        :value="check.system"
        :class="inputClass('system')"
        placeholder=""
        :disabled="disabled || fields.disabled.includes('system')"
        @input="$root.$emit('update:check', rule, { ...check, system: $event }, index)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('system')">
        {{ validFeedback["system"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('system')">
        {{ invalidFeedback["system"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- content_ref_name -->
    <b-form-group
      v-if="fields.displayed.includes('content_ref_name')"
      :id="`ruleEditor-check-content_ref_name-group-${mod}`"
    >
      <label :for="`ruleEditor-check-content_ref_name-${mod}`">
        Reference Name
        <i
          v-if="tooltips['content_ref_name']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['content_ref_name']"
        />
      </label>
      <b-form-input
        :id="`ruleEditor-check-content_ref_name-${mod}`"
        :value="check.content_ref_name"
        :class="inputClass('content_ref_name')"
        placeholder=""
        :disabled="disabled || fields.disabled.includes('content_ref_name')"
        @input="$root.$emit('update:check', rule, { ...check, content_ref_name: $event }, index)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('content_ref_name')">
        {{ validFeedback["content_ref_name"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('content_ref_name')">
        {{ invalidFeedback["content_ref_name"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- content_ref_href -->
    <b-form-group
      v-if="fields.displayed.includes('content_ref_href')"
      :id="`ruleEditor-check-content_ref_href-group-${mod}`"
    >
      <label :for="`ruleEditor-check-content_ref_href-${mod}`">
        Reference Link
        <i
          v-if="tooltips['content_ref_href']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['content_ref_href']"
        />
      </label>
      <b-form-input
        :id="`ruleEditor-check-content_ref_href-${mod}`"
        :value="check.content_ref_href"
        :class="inputClass('content_ref_href')"
        placeholder=""
        :disabled="disabled || fields.disabled.includes('content_ref_href')"
        @input="$root.$emit('update:check', rule, { ...check, content_ref_href: $event }, index)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('content_ref_href')">
        {{ validFeedback["content_ref_href"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('content_ref_href')">
        {{ invalidFeedback["content_ref_href"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- content -->
    <b-form-group
      v-if="fields.displayed.includes('content')"
      :id="`ruleEditor-check-content-group-${mod}`"
    >
      <label :for="`ruleEditor-check-content-${mod}`">
        Check
        <i
          v-if="tooltips['content']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['content']"
        />
      </label>
      <b-form-textarea
        :id="`ruleEditor-check-content-${mod}`"
        :value="check.content"
        :class="inputClass('content')"
        placeholder=""
        :disabled="disabled || fields.disabled.includes('content')"
        rows="1"
        max-rows="99"
        @input="$root.$emit('update:check', rule, { ...check, content: $event }, index)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('content')">
        {{ validFeedback["content"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('content')">
        {{ invalidFeedback["content"] }}
      </b-form-invalid-feedback>
    </b-form-group>
  </div>
</template>

<script>
import FormFeedbackMixinVue from "../../../mixins/FormFeedbackMixin.vue";

export default {
  name: "CheckForm",
  mixins: [FormFeedbackMixinVue],
  // `rule` and `index` are necessary if edits are to be made
  props: {
    rule: {
      type: Object,
    },
    index: {
      type: Number,
      default: -1,
    },
    disabled: {
      type: Boolean,
      required: true,
    },
    fields: {
      type: Object,
      default: () => {
        return {
          displayed: ["system", "content_ref_name", "content_ref_href", "content"],
          disabled: [],
        };
      },
    },
  },
  data: function () {
    return {
      mod: Math.floor(Math.random() * 1000),
    };
  },
  computed: {
    check: function () {
      return (this.rule.satisfied_by.length > 0 ? this.rule.satisfied_by[0] : this.rule)
        .checks_attributes[0];
    },
    tooltips: function () {
      return {
        system: null,
        content_ref_name: null,
        content_ref_href: null,
        content:
          this.rule.status === "Applicable - Configurable"
            ? "Describe how to validate that the remediation has been properly implemented"
            : [
                "Applicable - Does Not Meet",
                "Applicable - Inherently Meets",
                "Not Applicable",
              ].includes(this.rule.status)
            ? null
            : "Describe how to check for the presence of the vulnerability",
      };
    },
  },
};
</script>

<style scoped></style>
