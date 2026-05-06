<template>
  <div class="reaction-buttons my-2">
    <b-button
      size="sm"
      :variant="reactions.mine === 'up' ? 'primary' : 'outline-secondary'"
      class="reaction-btn"
      :disabled="disabled"
      :title="disabled ? closedMessage : ''"
      :pressed="reactions.mine === 'up'"
      :aria-label="`Thumbs up (${reactions.up})`"
      @click="$emit('toggle', 'up')"
    >
      <b-icon :icon="REACTION_ICONS.up" /> {{ reactions.up }}
    </b-button>
    <b-button
      size="sm"
      :variant="reactions.mine === 'down' ? 'primary' : 'outline-secondary'"
      class="reaction-btn ml-1"
      :disabled="disabled"
      :title="disabled ? closedMessage : ''"
      :pressed="reactions.mine === 'down'"
      :aria-label="`Thumbs down (${reactions.down})`"
      @click="$emit('toggle', 'down')"
    >
      <b-icon :icon="REACTION_ICONS.down" /> {{ reactions.down }}
    </b-button>

    <template v-if="totalReactions > 0">
      <b-button
        :id="popoverId"
        variant="link"
        size="sm"
        class="reactors-trigger ml-1"
        aria-label="Show reactor names"
      >
        <b-icon icon="people" />
      </b-button>
      <b-popover
        :target="popoverId"
        container="body"
        triggers="hover focus"
        placement="top"
        @show="onPopoverShow"
      >
        <div v-if="loading"><b-spinner small /> Loading reactors…</div>
        <div v-else-if="loadError" class="text-danger small" role="alert">
          Failed to load reactors.
        </div>
        <div v-else>
          <div v-if="reactors.up.length" class="mb-1">
            <strong>Thumbs up:</strong>
            {{ reactors.up.map((r) => r.name).join(", ") }}
          </div>
          <div v-if="reactors.down.length">
            <strong>Thumbs down:</strong>
            {{ reactors.down.map((r) => r.name).join(", ") }}
          </div>
        </div>
      </b-popover>
    </template>
  </div>
</template>

<script>
import axios from "axios";
import { REACTION_ICONS } from "../../constants/reactionVocabulary";

export default {
  name: "ReactionButtons",
  props: {
    reviewId: { type: [Number, String], required: true },
    reactions: {
      type: Object,
      required: true,
      validator: (v) => "up" in v && "down" in v,
    },
    disabled: { type: Boolean, default: false },
    closedMessage: {
      type: String,
      default: "Reactions are closed for this component.",
    },
  },
  data() {
    return {
      REACTION_ICONS,
      loading: false,
      loaded: false,
      loadError: false,
      reactors: { up: [], down: [] },
    };
  },
  computed: {
    popoverId() {
      return `reactors-popover-${this._uid}-${this.reviewId}`;
    },
    totalReactions() {
      return (this.reactions.up || 0) + (this.reactions.down || 0);
    },
  },
  watch: {
    reviewId() {
      this.loaded = false;
      this.reactors = { up: [], down: [] };
      this.loadError = false;
    },
  },
  methods: {
    async onPopoverShow() {
      if (this.loaded || this.loading) return;
      this.loading = true;
      this.loadError = false;
      try {
        const { data } = await axios.get(`/reviews/${this.reviewId}/reactions`, {
          headers: { Accept: "application/json" },
        });
        this.reactors = data;
        this.loaded = true;
      } catch {
        this.loadError = true;
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<style scoped>
/* WCAG 2.5.8 (AA) target size minimum is 24×24 CSS px; size="sm" lands
   roughly at 28×28 for the icon button. */
.reaction-btn {
  min-height: 28px;
}
.reactors-trigger {
  padding: 0 0.25rem;
}
</style>
