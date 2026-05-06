<script>
import axios from "axios";

// Shared optimistic-toggle + POST + revert flow for reaction surfaces.
// Consumers must also include AlertMixin (provides alertOrNotifyResponse).
// `apply` is a closure that writes a `{up, down, mine}` object back to the
// host component's state — each surface stores reactions slightly
// differently (this.replies[idx], this.rows[idx], $emit, this.$set on a
// review object), so the mixin stays state-agnostic.
export default {
  methods: {
    optimisticReactionToggle(prev, kind) {
      const next = { up: prev.up, down: prev.down, mine: null };
      if (prev.mine === kind) {
        next[kind] = Math.max(0, prev[kind] - 1);
        next.mine = null;
      } else if (prev.mine) {
        next[prev.mine] = Math.max(0, prev[prev.mine] - 1);
        next[kind] = prev[kind] + 1;
        next.mine = kind;
      } else {
        next[kind] = prev[kind] + 1;
        next.mine = kind;
      }
      return next;
    },
    async submitReactionToggle({ reviewId, prev, kind, apply }) {
      apply(this.optimisticReactionToggle(prev, kind));
      try {
        const { data } = await axios.post(
          `/reviews/${reviewId}/reactions`,
          { kind },
          { headers: { Accept: "application/json" } },
        );
        apply(data.reactions);
      } catch (err) {
        apply(prev);
        this.alertOrNotifyResponse(err);
      }
    },
  },
};
</script>
