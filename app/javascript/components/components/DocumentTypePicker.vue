<template>
  <b-form-group data-testid="document-type-picker">
    <template #label>
      <span class="font-weight-bold">What are you authoring?</span>
    </template>
    <b-form-radio-group :checked="value" stacked @input="$emit('input', $event)">
      <b-form-radio value="stig" data-testid="document-type-stig" class="mb-3">
        <div class="d-flex align-items-start">
          <b-icon icon="clipboard-check" font-scale="1.5" class="mr-3 text-primary" />
          <div>
            <div class="font-weight-bold">STIG</div>
            <small class="text-muted">
              Implement an existing SRG's requirements for a specific product (e.g. "Red Hat
              OpenShift STIG"). You'll work each requirement to a compliance posture: Configurable,
              Inherently Meets, Does Not Meet, or Not Applicable.
            </small>
          </div>
        </div>
      </b-form-radio>

      <b-form-radio value="srg" data-testid="document-type-srg" class="mb-2">
        <div class="d-flex align-items-start">
          <b-icon icon="journal-text" font-scale="1.5" class="mr-3 text-info" />
          <div>
            <div class="font-weight-bold">SRG</div>
            <small class="text-muted">
              Author a new Security Requirements Guide derived from core SRGs (e.g. "Container
              Platform SRG"). You'll decide which requirements apply to the technology and tailor
              their content.
            </small>
          </div>
        </div>
      </b-form-radio>
    </b-form-radio-group>
    <small class="text-muted d-block" data-testid="document-type-permanence">
      <b-icon icon="info-circle" class="mr-1" />
      This choice is permanent for the component.
    </small>
  </b-form-group>
</template>

<script>
/**
 * DocumentTypePicker - the creation-time "What are you authoring?" choice.
 *
 * The chosen profile posts as the component's document_type and is
 * immutable after creation, so each option carries a plain-language
 * description — the copy is LOCKED (do not reword; only line-wrapping
 * may change). Exclusive choice, no default: the author must pick.
 *
 * Usage:
 *   <DocumentTypePicker v-model="document_type" />
 *
 * Props:
 *   - value: String|null ("stig" | "srg", use v-model)
 *
 * Emits:
 *   - input: String - the selected profile key
 */
export default {
  name: "DocumentTypePicker",
  props: {
    value: {
      type: String,
      default: null,
    },
  },
};
</script>
