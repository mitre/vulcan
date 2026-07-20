<template>
  <b-alert v-if="count > 0 && token" show variant="info" class="d-flex align-items-center mb-3">
    <b-icon icon="box-arrow-in-right" class="mr-2" />
    <span>
      {{ count }} {{ count === 1 ? "requirement is" : "requirements are" }} marked for the
      {{ token }} family
    </span>
    <b-button
      variant="outline-info"
      size="sm"
      class="ml-auto"
      data-test="view-backlog"
      @click="$emit('view-backlog')"
    >
      View backlog
    </b-button>
  </b-alert>
</template>

<script>
/**
 * RelocationIntakeBanner - the creation/open-time intake prompt.
 *
 * Announces pending relocation markers destined for the open SRG
 * component's family and links to the backlog panel. A zero count or a
 * missing family token renders nothing — this is a notification
 * indicator, so absence is the meaning.
 *
 * Props:
 *   - count: Number - pending markers for the family
 *   - token: String|null - the family technology token
 *
 * Emits:
 *   - view-backlog: open the relocation backlog panel
 */
export default {
  name: "RelocationIntakeBanner",
  props: {
    count: {
      type: Number,
      required: true,
    },
    token: {
      type: String,
      default: null,
    },
  },
};
</script>
