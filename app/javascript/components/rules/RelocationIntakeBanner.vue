<template>
  <b-alert v-if="count > 0 && token" show variant="info" class="d-flex align-items-center mb-3">
    <b-icon icon="box-arrow-in-right" class="mr-2" />
    <span>
      {{ count }} {{ count === 1 ? "requirement is" : "requirements are" }} {{ terms.proposed }} for
      the {{ token }} SRG
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
import { RELOCATION_TERM } from "../../constants/terminology";

/**
 * RelocationIntakeBanner - the creation/open-time intake prompt.
 *
 * Announces open relocation proposals destined for the open component's
 * SRG and links to the backlog panel. A zero count or a missing
 * technology token renders nothing — this is a notification indicator,
 * so absence is the meaning.
 *
 * Props:
 *   - count: Number - open proposals for the SRG
 *   - token: String|null - the SRG's technology token
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
  data() {
    return {
      terms: RELOCATION_TERM,
    };
  },
};
</script>
