<template>
  <div>
    <!-- Collapsable header -->
    <div class="clickable" @click="showReviews = !showReviews">
      <h2 class="m-0 d-inline-block">Reviews &amp; Comments</h2>
      <b-badge pill class="ml-1 superVerticalAlign">{{ rule.reviews.length }}</b-badge>

      <b-icon v-if="showReviews" icon="chevron-down" />
      <b-icon v-if="!showReviews" icon="chevron-up" />
    </div>

    <b-collapse id="collapse-reviews" v-model="showReviews">
      <!-- All reviews -->
      <div v-for="review in shownReviews" :key="review.id">
        <p class="ml-2 mb-0 mt-2">
          <strong>{{ review.name }} - {{ actionDescriptions[review.action] }}</strong>
        </p>
        <p class="ml-2 mb-0">
          <small>{{ friendlyDateTime(review.created_at) }}</small>
        </p>
        <p class="ml-3 mb-2 white-space-pre-wrap">{{ review.comment }}</p>
      </div>
      <div class="d-flex justify-content-center align-items-center">
        <p
          v-if="numShownReviews < rule.reviews.length"
          class="text-primary clickable"
          @click="numShownReviews += 2"
        >
          show older reviews...
        </p>
        <p
          v-if="numShownReviews > 2 && rule.reviews.length > 2"
          class="ml-4 text-primary clickable"
          @click="numShownReviews -= 2"
        >
          hide older reviews...
        </p>
      </div>
    </b-collapse>
  </div>
</template>

<script>
import axios from "axios";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";

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
      showReviews: true,
      actionDescriptions: {
        comment: "Commented",
        request_review: "Requested Review",
        revoke_review_request: "Revoked Request for Review",
        request_changes: "Requested Changes",
        approve: "Approved",
        lock_control: "Locked",
        unlock_control: "Unlocked",
      },
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
