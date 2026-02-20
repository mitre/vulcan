<template>
  <div>
    <div class="mb-2">
      <strong>Reviews &amp; Comments</strong>
      <b-badge pill variant="info" class="ml-1">{{ rule.reviews.length }}</b-badge>
    </div>

    <div v-for="review in shownReviews" :key="review.id" class="mb-3">
      <p class="mb-0">
        <strong>{{ review.name }}</strong>
        <small class="text-muted ml-2">{{ actionDescriptions[review.action] }}</small>
      </p>
      <p class="mb-1">
        <small class="text-muted">{{ friendlyDateTime(review.created_at) }}</small>
      </p>
      <p class="mb-0 white-space-pre-wrap">{{ review.comment }}</p>
    </div>

    <p v-if="rule.reviews.length === 0" class="text-muted small">No reviews or comments yet.</p>

    <div v-if="rule.reviews.length > 2" class="d-flex justify-content-center">
      <b-button
        v-if="numShownReviews < rule.reviews.length"
        size="sm"
        variant="link"
        @click="numShownReviews += 2"
      >
        Show older...
      </b-button>
      <b-button v-if="numShownReviews > 2" size="sm" variant="link" @click="numShownReviews -= 2">
        Show fewer
      </b-button>
    </div>
  </div>
</template>

<script>
import axios from "axios";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";
import { ACTION_DESCRIPTIONS } from "../../constants/terminology";

export default {
  name: "RuleReviews",
  mixins: [DateFormatMixinVue, AlertMixinVue, FormMixinVue],
  props: {
    effectivePermissions: {
      type: String,
      required: false,
    },
    currentUserId: {
      type: Number,
      required: false,
    },
    rule: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return {
      numShownReviews: 2,
      actionDescriptions: ACTION_DESCRIPTIONS,
    };
  },
  computed: {
    shownReviews: function () {
      const sortedReviews = [...this.rule.reviews].sort(
        (a, b) => new Date(b.created_at) - new Date(a.created_at),
      );
      return sortedReviews.slice(0, this.numShownReviews);
    },
  },
};
</script>

<style scoped></style>
