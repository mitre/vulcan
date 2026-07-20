<template>
  <span>
    <span
      v-if="ruleOpen > 0"
      v-b-tooltip.hover
      :title="`${ruleOpen} open comments`"
      :data-test="`rule-open-comment-${rule.id}`"
      class="text-warning mr-1"
    >
      <b-icon icon="chat-left-text" aria-hidden="true" />
    </span>
    <b-icon
      v-if="rule.satisfies && rule.satisfies.length > 0"
      v-b-tooltip.hover
      icon="diagram-3"
      title="Satisfies other"
      aria-hidden="true"
      data-test="icon-satisfies"
    />
    <b-icon
      v-if="rule.satisfied_by && rule.satisfied_by.length > 0"
      v-b-tooltip.hover
      icon="files"
      :title="satisfiedByTooltip"
      aria-hidden="true"
      data-test="icon-satisfied-by"
    />
    <b-icon
      v-if="rule.review_requestor_id"
      v-b-tooltip.hover
      icon="file-earmark-search"
      title="Review requested"
      aria-hidden="true"
      data-test="icon-review-requested"
    />
    <b-icon
      v-if="rule.locked"
      v-b-tooltip.hover
      icon="lock"
      title="Locked"
      aria-hidden="true"
      data-test="icon-locked"
    />
    <b-icon
      v-if="rule.changes_requested"
      v-b-tooltip.hover
      icon="exclamation-triangle"
      title="Changes requested"
      aria-hidden="true"
      data-test="icon-changes-requested"
    />
    <!-- Pending relocation marker (SRG authoring): the pending record IS
         the marker — the badge follows the icon-family convention of
         absent-when-not-applicable. -->
    <b-icon
      v-if="pendingRelocation"
      v-b-tooltip.hover
      icon="box-arrow-right"
      :title="`Marked for relocation to ${pendingRelocation.target_technology_token}`"
      aria-hidden="true"
      data-test="icon-relocation"
    />
  </span>
</template>

<script>
export default {
  name: "RuleRowIcons",
  props: {
    rule: {
      type: Object,
      required: true,
    },
    ruleOpen: {
      type: Number,
      default: 0,
    },
    // The rule's pending relocation record ({ target_technology_token, ... })
    // or null — supplied by the page's relocation state, not the rule payload.
    pendingRelocation: {
      type: Object,
      default: null,
    },
  },
  computed: {
    satisfiedByTooltip() {
      const parents = this.rule.satisfied_by || [];
      const names = parents
        .map((p) => (p.component_prefix ? `${p.component_prefix}-${p.rule_id}` : p.rule_id))
        .filter(Boolean);
      return names.length > 0 ? `Satisfied by ${names.join(", ")}` : "Satisfied by other";
    },
  },
};
</script>
