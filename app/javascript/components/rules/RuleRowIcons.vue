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
      title="Satisfied by other"
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
  },
};
</script>
