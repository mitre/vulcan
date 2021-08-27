<template>
  <div v-if="check._destroy != true" class="card p-3 mb-3">
    <p>
      <strong>{{ check.id == null ? "New " : "" }}Check</strong>
    </p>

    <!-- system -->
    <b-form-group :id="`ruleEditor-check-system-group-${mod}`">
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
        v-model="check.system"
        :class="inputClass('system')"
        placeholder=""
        :disabled="disabled"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('system')">
        {{ validFeedback["system"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('system')">
        {{ invalidFeedback["system"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- content_ref_name -->
    <b-form-group :id="`ruleEditor-check-content_ref_name-group-${mod}`">
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
        v-model="check.content_ref_name"
        :class="inputClass('content_ref_name')"
        placeholder=""
        :disabled="disabled"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('content_ref_name')">
        {{ validFeedback["content_ref_name"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('content_ref_name')">
        {{ invalidFeedback["content_ref_name"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- content_ref_href -->
    <b-form-group :id="`ruleEditor-check-content_ref_href-group-${mod}`">
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
        v-model="check.content_ref_href"
        :class="inputClass('content_ref_href')"
        placeholder=""
        :disabled="disabled"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('content_ref_href')">
        {{ validFeedback["content_ref_href"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('content_ref_href')">
        {{ invalidFeedback["content_ref_href"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- content -->
    <b-form-group :id="`ruleEditor-check-content-group-${mod}`">
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
        v-model="check.content"
        :class="inputClass('content')"
        placeholder=""
        :disabled="disabled"
        rows="1"
        max-rows="99"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('content')">
        {{ validFeedback["content"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('content')">
        {{ invalidFeedback["content"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- Remove link -->
    <a v-if="!disabled" class="clickable text-dark" @click="$emit('removeCheck')">
      <i class="mdi mdi-trash-can" aria-hidden="true" />
      Remove Check
    </a>
  </div>
</template>

<script>
import FormFeedbackMixinVue from "../../../mixins/FormFeedbackMixin.vue";
export default {
  name: "CheckForm",
  mixins: [FormFeedbackMixinVue],
  props: {
    check: {
      type: Object,
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
      tooltips: {
        system: null,
        content_ref_name: null,
        content_ref_href: null,
        content: null,
      },
    };
  },
};
</script>

<style scoped></style>
